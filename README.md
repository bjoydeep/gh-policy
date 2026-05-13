# Global Hub Policy Repository

This repository contains policies for deployment via Global Hub using the ArgoCD GitOps pattern.

## Architecture Flow

```
ArgoCD (Global Hub) → mh-01 (Managed Hub) → jb-mc-01 (Managed Cluster)
```

1. **ArgoCD Application** deploys from this repo to `mh-01`
2. **Policy + Placement** gets applied on `mh-01`  
3. **ACM Policy Controller** distributes policy to `jb-mc-01`

### Two-Level ManagedClusterSetBinding Required

- **Global Hub**: `acm-integration/` resources expose managed hubs to ArgoCD
- **Managed Hub**: `managed-hub-setup/` resources expose managed clusters to policy placement

## Directory Structure

- `policies/` - Contains the actual policies and placements (deployed to `gh-policy` namespace)
- `argocd/` - Contains ArgoCD Application manifests  
- `acm-integration/` - Contains ACM-ArgoCD integration resources for **Global Hub**
- `managed-hub-setup/` - Contains setup resources for **Managed Hub** (apply on mh-01)
- `deploy.sh` - Automated deployment script for Global Hub side
- `kustomization.yaml` - Kustomize overlay for policy deployment

## Setup

### Initialize Git Repository

```bash
cd /path/to/gh-policy
git init
git add .
git commit -m "Initial commit: Global Hub namespace policy with ACM-ArgoCD integration"
git remote add origin git@github.com:YOUR-USERNAME/gh-policy.git
git push -u origin main
```

### Automated Deployment

Use the included deployment script:

```bash
./deploy.sh
```

Or follow the manual steps in [DEPLOYMENT.md](./DEPLOYMENT.md).

## Deployment

Deploy the ArgoCD Application to Global Hub:

```bash
oc apply -f argocd/namespace-policy-app.yaml
```

This will:
1. **Setup ACM-ArgoCD integration** (expose managed clusters to ArgoCD)
2. Create an ArgoCD Application on Global Hub  
3. Target the `mh-01` managed hub cluster via cluster-proxy
4. Deploy policies with placement targeting `jb-mc-01` to the `gh-policy` namespace
5. Let ACM policy controller handle the final distribution

## Prerequisites

- **Global Hub** with ACM + ArgoCD/OpenShift GitOps installed
- **Managed Hub** (mh-01) imported into Global Hub
- **Managed Cluster** (jb-mc-01) imported into mh-01