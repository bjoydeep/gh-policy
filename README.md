# Global Hub Multi-Hub Policy Repository

This repository contains policies for deployment via Global Hub using the ArgoCD GitOps pattern, designed for **multiple managed hubs and managed clusters** at scale.

## Architecture Flows

### Two-Tier Policy Distribution

```
1. Hub Policies:    ArgoCD (Global Hub) → mh-01, mh-02, mh-03... (Managed Hubs)
2. Cluster Policies: ArgoCD (Global Hub) → mh-01 → jb-mc-01, jb-mc-02... (Managed Clusters)
```

**Hub Policies**: Configure managed hub clusters themselves (network policies, RBAC, etc.)
**Cluster Policies**: Configure managed clusters via their hub (namespace policies, app policies, etc.)

### Two-Level ManagedClusterSetBinding Architecture

- **Global Hub**: `setup/acm-integration/` resources expose managed hubs to ArgoCD
- **Managed Hubs**: `setup/managed-hub-setup/` resources expose managed clusters to policy placement

## Directory Structure

```
├── hub-policies/                    # Policies FOR managed hubs (deployed to Global Hub)
│   ├── base/                       # Base policies for all managed hubs
│   └── overlays/                   # Environment-specific overlays
│       ├── production-hubs/
│       └── staging-hubs/
├── cluster-policies/               # Policies FOR managed clusters (deployed to managed hubs)
│   ├── base/                      # Base policies for all managed clusters  
│   └── overlays/                  # Environment-specific overlays
│       ├── development-clusters/
│       ├── staging-clusters/
│       └── production-clusters/
├── setup/                         # Setup resources (apply manually)
│   ├── acm-integration/          # Global Hub ACM-ArgoCD integration
│   └── managed-hub-setup/        # Setup for each managed hub
├── argocd/                        # ArgoCD Application manifests
│   ├── hub-policies-app.yaml     # Deploys hub policies TO Global Hub
│   └── mh-01-cluster-policies.yaml # Deploys cluster policies TO mh-01
└── deploy.sh                     # Automated deployment script

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

### Quick Start

Deploy both hub and cluster policies:

```bash
# Deploy hub policies (policies FOR managed hubs)
oc apply -f argocd/hub-policies-app.yaml

# Deploy cluster policies for mh-01 (policies FOR mh-01's managed clusters)
oc apply -f argocd/mh-01-cluster-policies.yaml
```

### Scaling to Multiple Managed Hubs

**For each new managed hub** (e.g., mh-02):

1. **Create ArgoCD Application** for cluster policies:
   ```bash
   # Copy and modify mh-01-cluster-policies.yaml
   cp argocd/mh-01-cluster-policies.yaml argocd/mh-02-cluster-policies.yaml
   # Update metadata.name and destination.name to mh-02
   ```

2. **Apply setup on the managed hub**:
   ```bash
   # On mh-02 cluster
   oc apply -f setup/managed-hub-setup/managedclustersetbinding-managed-hub.yaml
   ```

### What This Accomplishes

**Hub Policies Flow**:
1. ArgoCD deploys hub policies to Global Hub  
2. Global Hub policy controller distributes to managed hubs (mh-01, mh-02, etc.)
3. Policies configure the managed hub clusters themselves

**Cluster Policies Flow**:
1. ArgoCD deploys cluster policies to specific managed hubs
2. Managed hub policy controller distributes to their managed clusters
3. Policies configure the managed cluster workloads

## Prerequisites

- **Global Hub** with ACM + ArgoCD/OpenShift GitOps installed
- **Managed Hub** (mh-01) imported into Global Hub
- **Managed Cluster** (jb-mc-01) imported into mh-01