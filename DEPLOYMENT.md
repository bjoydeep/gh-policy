# Deployment Guide

## Prerequisites

1. **Global Hub** cluster with:
   - ACM (Advanced Cluster Management) installed
   - ArgoCD/OpenShift GitOps installed
2. **Managed Hub** (mh-01) imported into Global Hub
3. **Managed Cluster** (jb-mc-01) imported into mh-01
4. Git repository pushed to GitHub/GitLab

## Architecture Flow

```
GitHub Repo → ArgoCD (Global Hub) → mh-01 (Managed Hub) → jb-mc-01 (Managed Cluster)
     │              │                     │                      │
     └─────────────└─────────────────────└──────────────────────┘
              GitOps Deployment    ACM Policy Distribution
```

## Step 1: Setup Git Repository

### Push to GitHub (if not done already)
```bash
cd /path/to/gh-policy
git init
git add .
git commit -m "Initial commit: Global Hub namespace policy"
git remote add origin git@github.com:YOUR-USERNAME/gh-policy.git
git push -u origin main
```

### Update ArgoCD Application
Edit `argocd/namespace-policy-app.yaml` and update the `repoURL` field:

```yaml
source:
  repoURL: https://github.com/YOUR-USERNAME/gh-policy.git  # Update this!
```

## Step 2: Setup ACM-ArgoCD Integration

**CRITICAL**: Before deploying the ArgoCD application, you must set up the ACM-ArgoCD integration to expose managed clusters to ArgoCD.

### Create ManagedClusterSetBinding
```bash
oc apply -f acm-integration/managedclustersetbinding.yaml
```

This allows ArgoCD to access clusters in the `default` ManagedClusterSet.

### Create GitOpsCluster Resource
```bash
oc apply -f acm-integration/gitops-cluster.yaml
```

This creates:
- **GitOpsCluster**: Exposes `mh-01` to ArgoCD via cluster-proxy
- **Placement**: Selects the `mh-01` managed cluster

### Verify ACM-ArgoCD Integration
```bash
# Check that placement found the cluster
oc get placement mh-01-placement -n openshift-gitops

# Verify ArgoCD cluster secret was created
oc get secret -n openshift-gitops -l argocd.argoproj.io/secret-type=cluster
```

You should see:
- Placement with `SUCCEEDED=True` and `SELECTEDCLUSTERS=1`
- ArgoCD cluster secret like `mh-01-application-manager-cluster-secret`

## Step 3: Deploy ArgoCD Application

**From your Global Hub cluster:**

```bash
# Ensure you're on Global Hub
oc cluster-info

# Deploy the ArgoCD application
oc apply -f argocd/namespace-policy-app.yaml
```

## Step 4: Verify Deployment

### Check ArgoCD Application Status
```bash
oc get application namespace-policy-app -n openshift-gitops
```

Should show: `SYNC STATUS=Synced` and `HEALTH STATUS=Healthy`

### Check Deployed Resources on mh-01
```bash
# Switch to mh-01 context
export KUBECONFIG=/path/to/mh-01-kubeconfig.yaml

# Verify policy was deployed
oc get policy policy-namespace -n gh-policy
oc get placement policy-namespace-placement -n gh-policy
oc get placementbinding policy-namespace-binding -n gh-policy
```

### Check Policy Distribution to jb-mc-01

**IMPORTANT**: If the placement shows "No valid ManagedClusterSetBindings found", you need to create a ManagedClusterSetBinding on the **managed hub** (`mh-01`):

```bash
# Check what ManagedClusterSet jb-mc-01 belongs to
oc get managedclusterset
oc get managedcluster jb-mc-01 -o jsonpath='{.metadata.labels.cluster\.open-cluster-management\.io/clusterset}'

# Create ManagedClusterSetBinding (update clusterset name as needed)
# Use the file from managed-hub-setup/managedclustersetbinding-managed-hub.yaml
oc apply -f - <<EOF
apiVersion: cluster.open-cluster-management.io/v1beta2
kind: ManagedClusterSetBinding
metadata:
  name: default  # Update to match jb-mc-01's clusterset
  namespace: gh-policy
spec:
  clusterSet: default  # Update to match jb-mc-01's clusterset
EOF
```

Then check policy distribution:

```bash
# Check policy status
oc describe policy policy-namespace -n gh-policy

# Check placement decisions (should now show jb-mc-01)
oc get placementdecision -n gh-policy -o yaml

# Check compliance status
oc get policy policy-namespace -n gh-policy -o jsonpath='{.status.status[0].compliant}'
```

## Step 5: Verify Final Result

The policy should create a `prod` namespace on jb-mc-01:

```bash
# Check policy compliance details
oc describe policy policy-namespace -n gh-policy | grep -A10 "Compliant\|NonCompliant"

# If you have direct access to jb-mc-01, verify namespace exists
# oc --kubeconfig=/path/to/jb-mc-01-kubeconfig.yaml get namespace prod
```

## Understanding the Integration

### ACM-ArgoCD Integration Components

1. **ManagedClusterSetBinding**: Binds a ManagedClusterSet to a namespace, making clusters available to that namespace
2. **GitOpsCluster**: ACM resource that exposes selected clusters to ArgoCD
3. **Cluster-Proxy**: ACM provides cluster access via `cluster-proxy-addon-user.multicluster-engine.svc.cluster.local:9092/{CLUSTER_NAME}` instead of direct API server URLs

### URL Formats

- **Direct API**: `https://api.cluster-name.domain.com:6443` ❌ Won't work with ACM integration
- **Cluster-Proxy**: `https://cluster-proxy-addon-user.multicluster-engine.svc.cluster.local:9092/cluster-name` ✅ Required for ACM integration

## Troubleshooting

### ArgoCD Application Issues
```bash
oc describe application namespace-policy-app -n openshift-gitops
```

**Common Issues:**
- `cluster not found`: Missing GitOpsCluster or ManagedClusterSetBinding
- `sync failed`: Wrong repository URL or path
- `unhealthy`: Check Git repository accessibility

### ACM Integration Issues
```bash
# Check ManagedClusterSetBinding
oc get managedclustersetbinding default -n openshift-gitops

# Check GitOpsCluster
oc get gitopscluster mh-01-gitops-cluster -n openshift-gitops

# Check Placement
oc describe placement mh-01-placement -n openshift-gitops
```

### Policy Issues on mh-01
```bash
oc describe policy policy-namespace -n gh-policy
oc get events -n gh-policy --sort-by='.lastTimestamp'
```

### Placement Issues on Managed Hub
```bash
oc describe placement policy-namespace-placement -n gh-policy
oc get managedcluster jb-mc-01 --show-labels

# Check if ManagedClusterSetBinding exists in policy namespace
oc get managedclustersetbinding -n gh-policy

# If missing, create it:
# oc apply -f managed-hub-setup/managedclustersetbinding-managed-hub.yaml
```

### Common Issue: Two-Level ManagedClusterSetBinding

This architecture requires **two separate** ManagedClusterSetBindings:

1. **On Global Hub** (`openshift-gitops` namespace): Exposes managed hubs to ArgoCD
2. **On Managed Hub** (`gh-policy` namespace): Exposes managed clusters to policy placement

Both are required for the complete flow to work.

## Summary

This deployment demonstrates a **3-tier GitOps architecture**:

1. **ArgoCD** on Global Hub deploys policies to managed hubs
2. **ACM Policy Controller** on managed hubs distributes policies to managed clusters  
3. **Policy enforcement** happens on the target managed clusters

The key insight is that **ACM and ArgoCD integration** requires explicit setup via GitOpsCluster and ManagedClusterSetBinding resources, and uses cluster-proxy URLs rather than direct API access.