# Managed Hub Setup

This directory contains resources that must be applied **on the managed hub** to enable ArgoCD to manage ManagedClusterSetBindings automatically.

## Two Approaches

### Current Approach: ArgoCD-Managed (Recommended)

ArgoCD automatically creates the ManagedClusterSetBinding on the managed hub. **Only RBAC setup required:**

```bash
# On managed hub (mh-01):
oc apply -f argocd-rbac-for-managed-hub.yaml
```

### Legacy Approach: Manual (Archived)

```bash
# Manual approach (no longer needed):
# oc apply -f managedclustersetbinding-managed-hub.yaml
```

## Why RBAC is Needed

ArgoCD runs on Global Hub but deploys to managed hubs via cluster-proxy. The RBAC enables ArgoCD to:

1. Create policies, placements, and placementbindings
2. **Create ManagedClusterSetBinding** (requires special `managedclustersets/bind` permission)

## Files

- `argocd-rbac-for-managed-hub.yaml` - RBAC for ArgoCD to manage all policy resources including ManagedClusterSetBinding
- `managedclustersetbinding-managed-hub.yaml` - Legacy manual approach (archived)