# Global Hub Policy Repository

This repository contains policies for deployment via Global Hub using the ArgoCD GitOps pattern.

## Architecture Flow

```
ArgoCD (Global Hub) → mh-01 (Managed Hub) → jb-mc-01 (Managed Cluster)
```

1. **ArgoCD Application** deploys from this repo to `mh-01`
2. **Policy + Placement** gets applied on `mh-01`  
3. **ACM Policy Controller** distributes policy to `jb-mc-01`

## Directory Structure

- `policies/` - Contains the actual policies and placements (deployed to `gh-policy` namespace)
- `argocd/` - Contains ArgoCD Application manifests
- `kustomization.yaml` - Kustomize overlay for policy deployment

## Deployment

Deploy the ArgoCD Application to Global Hub:

```bash
oc apply -f argocd/namespace-policy-app.yaml
```

This will:
1. Create an ArgoCD Application on Global Hub
2. Target the `mh-01` managed hub cluster
3. Deploy policies with placement targeting `jb-mc-01` to the `gh-policy` namespace
4. Let ACM policy controller handle the final distribution