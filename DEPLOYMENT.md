# Deployment Guide

## Prerequisites

1. **Global Hub** cluster with ArgoCD/OpenShift GitOps installed
2. **Managed Hub** (mh-01) imported into Global Hub
3. **Managed Cluster** (jb-mc-01) imported into mh-01
4. Git repository pushed to GitHub/GitLab

## Step 1: Update Git Repository URL

Edit `argocd/namespace-policy-app.yaml` and update the `repoURL` field:

```yaml
source:
  repoURL: https://github.com/YOUR-USERNAME/gh-policy.git  # Update this!
```

## Step 2: Deploy ArgoCD Application

From your **Global Hub cluster**:

```bash
# Ensure you're on Global Hub
oc cluster-info

# Deploy the ArgoCD application
oc apply -f argocd/namespace-policy-app.yaml
```

## Step 3: Verify Deployment

Check ArgoCD application status:

```bash
oc get application namespace-policy-app -n openshift-gitops
```

Check if resources are synced to mh-01:

```bash
# Switch to mh-01 context
export KUBECONFIG=/path/to/mh-01-kubeconfig.yaml

# Verify policy was deployed
oc get policy policy-namespace -n gh-policy
oc get placement policy-namespace-placement -n gh-policy
oc get placementbinding policy-namespace-binding -n gh-policy
```

Check policy distribution to jb-mc-01:

```bash
# Check policy status
oc describe policy policy-namespace -n gh-policy

# Check placement decisions
oc get placementdecision -n gh-policy
```

## Step 4: Verify on Target Cluster

The policy should create a `prod` namespace on jb-mc-01:

```bash
# If you have direct access to jb-mc-01
oc get namespace prod
```

## Troubleshooting

### ArgoCD Application Issues
```bash
oc describe application namespace-policy-app -n openshift-gitops
```

### Policy Issues on mh-01
```bash
oc describe policy policy-namespace -n gh-policy
oc get events -n gh-policy
```

### Placement Issues
```bash
oc describe placement policy-namespace-placement -n gh-policy
oc get managedcluster jb-mc-01 --show-labels
```