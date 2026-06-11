# Private AKS Deployment Implementation - Executive Summary

## What Was Changed

Your GitHub Actions workflow has been refactored to deploy to a **private AKS cluster** using a **Jump VM** as the deployment intermediary. This eliminates the need for direct network access from GitHub-hosted runners to your private Kubernetes cluster.

### Files Modified

| File | Change |
|------|--------|
| `.github/workflows/deploy.yml` | **Complete deploy job refactor** — Replaced kubectl/Helm execution with `az vm run-command invoke` |
| `terraform/modules/vm/outputs.tf` | **Added outputs** — `vm_principal_id`, `vm_name`, `vm_resource_group_name` |
| `terraform/environments/dev/rbac.tf` | **New file** — 3 role assignments for Jump VM managed identity |

---

## Deployment Architecture

### Before (Direct Access - ❌ Not Suitable for Private AKS)
```
GitHub Actions → [Public Network] → Private AKS
   ❌ Cannot reach private API server
```

### After (Jump VM Intermediary - ✅ Recommended for Private AKS)
```
GitHub Actions
    ↓ Azure Login (managed identity)
    ↓ az vm run-command invoke
Jump VM (Private Subnet)
    ↓ kubectl + Helm (on private network)
    ↓ AKS Authentication (managed identity)
Private AKS Cluster ✓
```

---

## How It Works

### 1. GitHub Actions Builds Docker Images (Unchanged)
```yaml
build-backend:
  - Compile Java with Maven
  - Build Docker image
  - Push to ACR ✓

build-frontend:
  - Build Node.js app
  - Build Docker image
  - Push to ACR ✓
```

### 2. GitHub Actions Authenticates to Azure
```yaml
- name: Azure Login
  uses: azure/login@v1
  with:
    creds: ${{ secrets.AZURE_CREDENTIALS }}
```

### 3. GitHub Actions Invokes Deployment Script on Jump VM
```bash
az vm run-command invoke \
  --resource-group rg-dev \
  --name dev-jumpvm \
  --command-id RunShellScript \
  --scripts "/opt/deploy/deploy.sh \
    --resource-group rg-dev \
    --cluster aks-dev \
    --tag <COMMIT_SHA> \
    --registry myacr.azurecr.io"
```

### 4. Jump VM Executes Deployment
```bash
# On Jump VM:
/opt/deploy/deploy.sh runs:

az aks get-credentials --resource-group rg-dev --name aks-dev
helm upgrade --install ... --set image.tag=<COMMIT_SHA>
kubectl rollout status deployment/ems-backend
```

### 5. Private AKS Receives Updates
```
AKS API Server (Private)
├─ New backend image deployed
├─ New frontend image deployed
├─ Pods rolling out
└─ Service updated
```

---

## Parameters Passed to Jump VM

```bash
/opt/deploy/deploy.sh \
  --resource-group '<RESOURCE_GROUP>'      # e.g., rg-dev
  --cluster '<AKS_CLUSTER_NAME>'           # e.g., aks-dev
  --tag '<IMAGE_TAG>'                      # e.g., abc1234567890
  --registry '<ACR_LOGIN_SERVER>'          # e.g., myacr.azurecr.io
```

These are set from GitHub secrets and computed from the workflow context.

---

## What Stayed the Same

✅ Docker image build process (Maven backend, Node.js frontend)  
✅ ACR authentication and image push  
✅ Helm chart configuration  
✅ Kubernetes manifests  
✅ GitHub Actions secret-based authentication  

---

## What Changed

❌ **Removed** — Direct `kubectl` commands from GitHub runner  
❌ **Removed** — Direct `helm` deployments from GitHub runner  
❌ **Removed** — AKS credential retrieval in GitHub Actions  
❌ **Removed** — Network connectivity requirement to private AKS API  

✅ **Added** — `az vm run-command invoke` to Jump VM  
✅ **Added** — Role assignments for Jump VM managed identity  
✅ **Added** — Deployment script template for Jump VM  
✅ **Added** — Deployment status check step  
✅ **Added** — Documentation and setup guides  

---

## Required Setup Steps

### 1. GitHub Secrets (Add These)
```
TF_VAR_SUBSCRIPTION_ID          # Your Azure subscription ID
TF_VAR_ACR_NAME                 # Container registry name (e.g., myacr)
TF_VAR_AKS_CLUSTER_NAME         # AKS cluster name (e.g., aks-dev)
TF_VAR_RESOURCE_GROUP_NAME      # Resource group (e.g., rg-dev)
TF_VAR_ENVIRONMENT_PREFIX       # Environment prefix (e.g., dev)
AZURE_CREDENTIALS               # Already exists
```

### 2. Jump VM Setup
1. Install `kubectl`, `helm`, `az` CLI
2. Create `/opt/deploy/deploy.sh` with deployment logic
3. Make executable: `chmod +x /opt/deploy/deploy.sh`

### 3. RBAC Configuration
1. Ensure Jump VM has system-assigned managed identity
2. Assign `Azure Kubernetes Service Cluster User Role` on AKS
3. Assign `Reader` role on resource group
4. Assign `AcrPull` role on ACR

### 4. Test
```bash
# On Jump VM, manually test the deployment script
/opt/deploy/deploy.sh \
  --resource-group rg-dev \
  --cluster aks-dev \
  --tag test-1234 \
  --registry myacr.azurecr.io
```

---

## Deployment Flow Diagram

```
┌──────────────────────────────────────────────────────────┐
│              GitHub Actions Workflow                      │
│ .github/workflows/deploy.yml                             │
├──────────────────────────────────────────────────────────┤
│                                                            │
│ 1. Detect Changes                                        │
│    └─ Scan modified files (backend/frontend/helm)        │
│                                                            │
│ 2. Build Backend                                         │
│    ├─ Checkout                                           │
│    ├─ Setup Java 17                                      │
│    ├─ mvn clean package                                  │
│    ├─ Azure Login                                        │
│    ├─ docker build & push to ACR                         │
│    └─ Tag: <COMMIT_SHA>, latest, <BRANCH>               │
│                                                            │
│ 3. Build Frontend                                        │
│    ├─ Checkout                                           │
│    ├─ Setup Node.js 18                                   │
│    ├─ npm install & npm run build                        │
│    ├─ Azure Login                                        │
│    ├─ docker build & push to ACR                         │
│    └─ Tag: <COMMIT_SHA>, latest, <BRANCH>               │
│                                                            │
│ 4. Deploy to Private AKS [NEW]                           │
│    ├─ Checkout                                           │
│    ├─ Azure Login                                        │
│    ├─ Invoke Jump VM Run Command:                        │
│    │  └─ /opt/deploy/deploy.sh \                         │
│    │     --resource-group rg-dev \                       │
│    │     --cluster aks-dev \                             │
│    │     --tag <COMMIT_SHA> \                            │
│    │     --registry myacr.azurecr.io                     │
│    ├─ Check Deployment Status (via Jump VM)             │
│    └─ Store Deployment Summary Artifact                 │
│                                                            │
└──────────────────────────────────────────────────────────┘
                           │
                           │ (az vm run-command)
                           ▼
┌──────────────────────────────────────────────────────────┐
│           Jump VM (Private Subnet)                       │
│           System-Assigned Managed Identity               │
├──────────────────────────────────────────────────────────┤
│                                                            │
│ Execute: /opt/deploy/deploy.sh                           │
│                                                            │
│ ├─ Parse: --resource-group, --cluster, --tag, --registry│
│ ├─ az aks get-credentials (via managed identity)         │
│ ├─ helm repo add & helm repo update                      │
│ ├─ helm upgrade --install \                              │
│ │  --set backend.image.tag=<COMMIT_SHA> \               │
│ │  --set frontend.image.tag=<COMMIT_SHA> \              │
│ │  --set registry.name=myacr.azurecr.io                 │
│ ├─ kubectl rollout status (backend & frontend)          │
│ └─ kubectl get pods/svc/deployments (status report)     │
│                                                            │
└──────────────────────────────────────────────────────────┘
                           │
                           │ (private network)
                           ▼
┌──────────────────────────────────────────────────────────┐
│           Private AKS Cluster                            │
│           (No public ingress required)                    │
├──────────────────────────────────────────────────────────┤
│                                                            │
│ Namespace: employee-management                           │
│                                                            │
│ Deployments:                                             │
│  ├─ ems-backend (new image, <COMMIT_SHA>)               │
│  └─ ems-frontend (new image, <COMMIT_SHA>)              │
│                                                            │
│ Pods:                                                    │
│  ├─ ems-backend-xxxxx (1/1 Running)                     │
│  └─ ems-frontend-xxxxx (1/1 Running)                    │
│                                                            │
│ Services:                                                │
│  ├─ ems-backend (ClusterIP)                             │
│  └─ ems-frontend (ClusterIP)                            │
│                                                            │
└──────────────────────────────────────────────────────────┘
```

---

## Key Advantages

| Feature | Benefit |
|---------|---------|
| **No Direct GitHub → AKS Access** | Private AKS API server remains completely private |
| **Managed Identity** | No credentials stored in secrets; uses Azure RBAC |
| **Audit Trail** | All deployments logged via Azure Activity Log |
| **Scalable** | Same pattern works for multiple AKS clusters |
| **Secure** | Jump VM restricted by NSG; deployment script runs with least privilege |
| **Simple Integration** | Leverages existing GitHub Secrets and Azure authentication |

---

## Quick Start

1. **Add GitHub Secrets** (Settings > Secrets > Actions):
   ```
   TF_VAR_ENVIRONMENT_PREFIX = "dev"
   TF_VAR_RESOURCE_GROUP_NAME = "rg-dev"
   TF_VAR_AKS_CLUSTER_NAME = "aks-dev"
   TF_VAR_ACR_NAME = "myacr"
   TF_VAR_SUBSCRIPTION_ID = "<SUBSCRIPTION_ID>"
   ```

2. **Create Deployment Script** on Jump VM:
   ```bash
   ssh azureuser@<JUMP_VM_PUBLIC_IP>
   mkdir -p /opt/deploy
   # Copy deploy.sh template from PRIVATE_AKS_DEPLOYMENT_GUIDE.md
   chmod +x /opt/deploy/deploy.sh
   ```

3. **Test Manually**:
   ```bash
   /opt/deploy/deploy.sh \
     --resource-group rg-dev \
     --cluster aks-dev \
     --tag test-1234 \
     --registry myacr.azurecr.io
   ```

4. **Trigger Workflow**:
   - Merge a branch to main (or trigger "Terraform Infrastructure Pipeline")
   - Watch GitHub Actions for "Build and Deploy to AKS"

---

## Documentation Reference

| Document | Purpose |
|----------|---------|
| [SETUP_CHECKLIST.md](.github/SETUP_CHECKLIST.md) | Step-by-step implementation checklist |
| [PRIVATE_AKS_DEPLOYMENT_GUIDE.md](.github/PRIVATE_AKS_DEPLOYMENT_GUIDE.md) | Complete setup guide with example scripts |
| [WORKFLOW_CHANGES.md](.github/WORKFLOW_CHANGES.md) | Before/after YAML comparison |
| [WORKFLOW_YAML_REFERENCE.md](.github/WORKFLOW_YAML_REFERENCE.md) | Full deploy job YAML reference |
| [terraform/JUMPVM_RBAC_SETUP.md](../terraform/JUMPVM_RBAC_SETUP.md) | Terraform RBAC configuration |

---

## Support & Troubleshooting

See [SETUP_CHECKLIST.md](.github/SETUP_CHECKLIST.md) for:
- Pre-deployment checklist
- Verification commands
- Troubleshooting guide
- Security best practices

---

**Status**: ✅ Ready for implementation  
**Last Updated**: 2026-06-10
