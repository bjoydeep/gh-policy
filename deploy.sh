#!/bin/bash

# Global Hub Policy Deployment Script
# This script automates the deployment of policies from Global Hub to managed clusters

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

check_prereq() {
    log "Checking prerequisites..."

    # Check if on Global Hub cluster
    if ! oc get ns multicluster-global-hub > /dev/null 2>&1; then
        error "Not connected to Global Hub cluster (multicluster-global-hub namespace not found)"
    fi

    # Check if GitOps is installed
    if ! oc get ns openshift-gitops > /dev/null 2>&1; then
        error "OpenShift GitOps not installed (openshift-gitops namespace not found)"
    fi

    # Check if mh-01 is imported
    if ! oc get managedcluster mh-01 > /dev/null 2>&1; then
        error "Managed hub 'mh-01' not imported"
    fi

    log "Prerequisites check passed ✓"
}

deploy_acm_integration() {
    log "Deploying ACM-ArgoCD integration resources..."

    # Deploy ManagedClusterSetBinding and GitOpsCluster
    oc apply -f acm-integration/

    # Wait for placement to be satisfied
    log "Waiting for placement to be satisfied..."
    timeout 120s bash -c 'while [[ $(oc get placement mh-01-placement -n openshift-gitops -o jsonpath="{.status.conditions[?(@.type==\"PlacementSatisfied\")].status}" 2>/dev/null) != "True" ]]; do sleep 5; done'

    # Verify cluster secret was created
    if oc get secret -n openshift-gitops -l argocd.argoproj.io/secret-type=cluster | grep -q mh-01; then
        log "ACM-ArgoCD integration successful ✓"
    else
        error "ACM-ArgoCD integration failed - cluster secret not created"
    fi
}

deploy_argocd_app() {
    log "Deploying ArgoCD application..."

    # Deploy the ArgoCD application
    oc apply -f argocd/namespace-policy-app.yaml

    # Wait for sync to complete
    log "Waiting for ArgoCD application to sync..."
    timeout 180s bash -c 'while [[ $(oc get applications.argoproj.io namespace-policy-app -n openshift-gitops -o jsonpath="{.status.sync.status}" 2>/dev/null) != "Synced" ]]; do sleep 10; done'

    # Check health status
    if [[ $(oc get applications.argoproj.io namespace-policy-app -n openshift-gitops -o jsonpath="{.status.health.status}") == "Healthy" ]]; then
        log "ArgoCD application deployment successful ✓"
    else
        error "ArgoCD application deployment failed"
    fi
}

show_status() {
    log "Deployment Status Summary:"
    echo
    echo "🎯 ArgoCD Application:"
    oc get applications.argoproj.io namespace-policy-app -n openshift-gitops
    echo
    echo "📦 Synced Resources:"
    oc get applications.argoproj.io namespace-policy-app -n openshift-gitops -o jsonpath='{.status.operationState.syncResult.resources[*].kind}' | tr ' ' '\n' | sort | uniq
    echo
    log "Next steps:"
    echo "1. Verify policy deployment on mh-01:"
    echo "   kubectl --kubeconfig=/path/to/mh-01-kubeconfig.yaml get policy policy-namespace -n gh-policy"
    echo
    echo "2. If placement shows 'No valid ManagedClusterSetBindings found', apply on mh-01:"
    echo "   kubectl --kubeconfig=/path/to/mh-01-kubeconfig.yaml apply -f managed-hub-setup/"
    echo
    echo "3. Verify policy distribution to jb-mc-01:"
    echo "   kubectl --kubeconfig=/path/to/mh-01-kubeconfig.yaml get placementdecision -n gh-policy"
}

# Main execution
main() {
    log "Starting Global Hub policy deployment..."
    echo

    check_prereq
    deploy_acm_integration
    deploy_argocd_app
    show_status

    log "Deployment completed successfully! 🎉"
}

# Run main function
main