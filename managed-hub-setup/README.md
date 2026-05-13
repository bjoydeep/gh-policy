# Managed Hub Setup

This directory contains resources that must be applied **on the managed hub** (mh-01) for policy distribution to work correctly.

## Why This is Needed

The policy distribution flow requires **two-level ManagedClusterSetBindings**:

1. **Global Hub** (`acm-integration/`): Exposes managed hubs to ArgoCD
2. **Managed Hub** (this directory): Exposes managed clusters to policy placement

## Usage

**On the managed hub (mh-01):**

```bash
# Check what ManagedClusterSet your managed clusters belong to
oc get managedclusterset
oc get managedcluster jb-mc-01 -o jsonpath='{.metadata.labels.cluster\.open-cluster-management\.io/clusterset}'

# Update the managedclustersetbinding-managed-hub.yaml with the correct clusterset name
# Then apply:
oc apply -f managedclustersetbinding-managed-hub.yaml
```

## Files

- `managedclustersetbinding-managed-hub.yaml` - Binds the managed cluster's clusterset to the policy namespace