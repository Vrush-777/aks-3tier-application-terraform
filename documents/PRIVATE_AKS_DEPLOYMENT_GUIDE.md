# Private AKS Deployment via Jump VM - GitHub Actions Integration

## Overview

This GitHub Actions workflow has been modified to deploy to a **private AKS cluster** using a **Jump VM**. Instead of running `kubectl` and `helm` commands directly from the GitHub-hosted runner, the workflow:

1. Builds Docker images for backend and frontend
2. Pushes images to Azure Container Registry (ACR)
3. **Invokes a deployment script on the Jump VM** using `az vm run-command invoke`
4. The Jump VM script handles all kubectl/Helm operations

## Architecture Diagram

```
GitHub Actions Runner (ubuntu-latest)
    │
    ├─ Build & Push Backend image to ACR
    ├─ Build & Push Frontend image to ACR
    │
    └─ Azure Login (via AZURE_CREDENTIALS)
         │
         └─ az vm run-command invoke
              │
              └─ Jump VM (/opt/deploy/deploy.sh)
                   │
                   ├─ kubectl apply / helm upgrade
                   ├─ AKS API access (via managed identity)
                   └─ ACR access (via managed identity)
                        │
                        └─ Private AKS Cluster
```

## Deployment Workflow Changes

### Previous Workflow (Direct from GitHub Runner)
❌ ~~Get AKS credentials~~  
❌ ~~Run helm commands from GitHub runner~~  
❌ ~~Run kubectl commands from GitHub runner~~  

### New Workflow (via Jump VM)
✅ Azure Login (stored in AZURE_CREDENTIALS secret)  
✅ Invoke deployment script on Jump VM  
✅ Jump VM executes all kubectl/Helm operations  

## GitHub Actions Secrets Configuration

Add these secrets to your GitHub repository:

| Secret Name | Value | Description |
|---|---|---|
| `AZURE_CREDENTIALS` | **Required** | JSON service principal credentials (already exists) |
| `TF_VAR_SUBSCRIPTION_ID` | **Required** | Azure subscription ID |
| `TF_VAR_ACR_NAME` | **Required** | ACR registry name (e.g., `myacr`) |
| `TF_VAR_AKS_CLUSTER_NAME` | **Required** | AKS cluster name |
| `TF_VAR_RESOURCE_GROUP_NAME` | **Required** | Resource group name |
| `TF_VAR_ENVIRONMENT_PREFIX` | **Required** | Environment prefix for Jump VM naming (e.g., `dev`, `prod`) |
| `JUMP_VM_NAME` | Optional | Jump VM name (if not provided, defaults to `{PREFIX}-jumpvm`) |

**Jump VM Name Inference:**

If `JUMP_VM_NAME` secret is not set, the workflow will construct it as:
```
JUMP_VM_NAME = "${TF_VAR_ENVIRONMENT_PREFIX}-jumpvm"
# Example: dev-jumpvm, prod-jumpvm
```

## Jump VM Deployment Script

### Script Location
```
/opt/deploy/deploy.sh
```

### Script Parameters

The workflow passes these environment variables to the deployment script:

```bash
/opt/deploy/deploy.sh \
  --resource-group <RESOURCE_GROUP> \
  --cluster <AKS_CLUSTER_NAME> \
  --tag <IMAGE_TAG> \
  --registry <ACR_LOGIN_SERVER>
```

**Parameters Explanation:**

| Parameter | Source | Example |
|---|---|---|
| `--resource-group` | `RESOURCE_GROUP` env var | `rg-dev` |
| `--cluster` | `AKS_CLUSTER_NAME` env var | `aks-dev` |
| `--tag` | GitHub commit SHA | `abc1234567890def...` |
| `--registry` | `ACR_LOGIN_SERVER` env var | `myacr.azurecr.io` |

### Example Deploy Script Template

Create this script on your Jump VM at `/opt/deploy/deploy.sh`:

```bash
#!/bin/bash

set -e

# =============================================================================
# Private AKS Deployment Script
# Runs on Jump VM to deploy to private AKS cluster
# Invoked by GitHub Actions via: az vm run-command invoke
# =============================================================================

# Parse command-line arguments
RESOURCE_GROUP=""
AKS_CLUSTER_NAME=""
IMAGE_TAG=""
ACR_LOGIN_SERVER=""
DEPLOYMENT_NAMESPACE="employee-management"
HELM_CHART_PATH="/home/azureuser/ems-3tier/helm/employee-management-system"
HELM_RELEASE="employee-management-system"

while [[ $# -gt 0 ]]; do
  case $1 in
    --resource-group)
      RESOURCE_GROUP="$2"
      shift 2
      ;;
    --cluster)
      AKS_CLUSTER_NAME="$2"
      shift 2
      ;;
    --tag)
      IMAGE_TAG="$2"
      shift 2
      ;;
    --registry)
      ACR_LOGIN_SERVER="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

# Validate required parameters
if [[ -z "$RESOURCE_GROUP" || -z "$AKS_CLUSTER_NAME" || -z "$IMAGE_TAG" || -z "$ACR_LOGIN_SERVER" ]]; then
  echo "ERROR: Missing required parameters"
  echo "Usage: $0 --resource-group <RG> --cluster <CLUSTER> --tag <TAG> --registry <REGISTRY>"
  exit 1
fi

echo "=========================================="
echo "Private AKS Deployment"
echo "=========================================="
echo "Resource Group: $RESOURCE_GROUP"
echo "AKS Cluster: $AKS_CLUSTER_NAME"
echo "Image Tag: $IMAGE_TAG"
echo "ACR Registry: $ACR_LOGIN_SERVER"
echo "Helm Release: $HELM_RELEASE"
echo "Namespace: $DEPLOYMENT_NAMESPACE"
echo "=========================================="

# Ensure kubectl is configured for the private AKS cluster
echo "Configuring kubectl for private AKS cluster..."
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_CLUSTER_NAME" \
  --overwrite-existing

# Verify cluster connectivity
echo "Verifying cluster connectivity..."
kubectl cluster-info

# Create deployment namespace if it doesn't exist
echo "Creating namespace: $DEPLOYMENT_NAMESPACE"
kubectl create namespace "$DEPLOYMENT_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Update Helm repositories
echo "Updating Helm repositories..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Dry-run the Helm deployment
echo "Performing Helm dry-run..."
helm upgrade --install "$HELM_RELEASE" \
  "$HELM_CHART_PATH" \
  --namespace "$DEPLOYMENT_NAMESPACE" \
  --values "$HELM_CHART_PATH/values.yaml" \
  --values "$HELM_CHART_PATH/values-dev.yaml" \
  --set backend.image.tag="$IMAGE_TAG" \
  --set frontend.image.tag="$IMAGE_TAG" \
  --set registry.name="$ACR_LOGIN_SERVER" \
  --dry-run \
  --debug

# Deploy to AKS
echo "Deploying to AKS cluster..."
helm upgrade --install "$HELM_RELEASE" \
  "$HELM_CHART_PATH" \
  --namespace "$DEPLOYMENT_NAMESPACE" \
  --values "$HELM_CHART_PATH/values.yaml" \
  --values "$HELM_CHART_PATH/values-dev.yaml" \
  --set backend.image.tag="$IMAGE_TAG" \
  --set frontend.image.tag="$IMAGE_TAG" \
  --set registry.name="$ACR_LOGIN_SERVER" \
  --wait \
  --timeout 10m \
  --atomic

# Wait for deployments
echo "Waiting for deployments to be ready..."
kubectl rollout status deployment/ems-backend \
  -n "$DEPLOYMENT_NAMESPACE" \
  --timeout=5m
kubectl rollout status deployment/ems-frontend \
  -n "$DEPLOYMENT_NAMESPACE" \
  --timeout=5m

# Display deployment status
echo "=========================================="
echo "Deployment Status"
echo "=========================================="
echo "Deployments:"
kubectl get deployments -n "$DEPLOYMENT_NAMESPACE"

echo ""
echo "Pods:"
kubectl get pods -n "$DEPLOYMENT_NAMESPACE"

echo ""
echo "Services:"
kubectl get svc -n "$DEPLOYMENT_NAMESPACE"

echo ""
echo "Ingress:"
kubectl get ingress -n "$DEPLOYMENT_NAMESPACE" || echo "No Ingress found"

echo "=========================================="
echo "Deployment completed successfully!"
echo "=========================================="
```

### Setting Up the Script

1. **SSH into the Jump VM**:
   ```bash
   ssh azureuser@<JUMP_VM_PUBLIC_IP>
   ```

2. **Create the deployment directory**:
   ```bash
   mkdir -p /opt/deploy
   sudo chown azureuser:azureuser /opt/deploy
   ```

3. **Upload the deployment script**:
   ```bash
   # Option A: Copy from local machine
   scp deploy.sh azureuser@<JUMP_VM_PUBLIC_IP>:/opt/deploy/

   # Option B: Clone the repo on Jump VM
   cd /home/azureuser
   git clone <REPO_URL> ems-3tier
   cp ems-3tier/scripts/deploy.sh /opt/deploy/
   ```

4. **Make the script executable**:
   ```bash
   chmod +x /opt/deploy/deploy.sh
   ```

5. **Verify the script can run** (requires `kubectl` and `helm` to be installed on Jump VM):
   ```bash
   /opt/deploy/deploy.sh --help
   ```

## GitHub Actions Workflow Execution

### Workflow Trigger
The workflow is triggered when the **Terraform Infrastructure Pipeline** completes successfully:

```yaml
on:
  workflow_run:
    workflows:
      - Terraform Infrastructure Pipeline
    types:
      - completed
```

### Workflow Steps

1. **Detect Changes** — Scan for backend/frontend/helm changes
2. **Build Backend** — Compile Java, build Docker image, push to ACR
3. **Build Frontend** — Build Node.js app, build Docker image, push to ACR
4. **Deploy via Jump VM** — Invoke deployment script on Jump VM

### Workflow Outputs

The workflow produces these artifacts:

- `deployment-summary-<RUN_ID>` — Summary of deployment parameters and timestamp

## Monitoring Deployment

### View Workflow Status
1. Go to **Actions** tab in GitHub
2. Select **Build and Deploy to AKS** workflow
3. Click the latest run

### Check Deployment Logs on Jump VM
```bash
ssh azureuser@<JUMP_VM_PUBLIC_IP>

# View recent deployment script output
journalctl -u cloud-init -n 100 -f

# Check kubectl deployments
kubectl get deployments -n employee-management
kubectl get pods -n employee-management
kubectl logs deployment/ems-backend -n employee-management
```

## Troubleshooting

### Issue: "No credentials provided" error

**Cause**: `AZURE_CREDENTIALS` secret is missing or malformed.

**Solution**:
1. Regenerate the service principal:
   ```bash
   az ad sp create-for-rbac --role Contributor --scopes /subscriptions/<SUBSCRIPTION_ID>
   ```
2. Update the GitHub secret with the JSON output.

### Issue: "Jump VM not found" error

**Cause**: JUMP_VM_NAME secret is incorrect or Jump VM doesn't exist.

**Solution**:
1. Verify Jump VM exists:
   ```bash
   az vm list -g <RESOURCE_GROUP> --query "[].name"
   ```
2. Set `JUMP_VM_NAME` secret to the exact VM name.

### Issue: "Run command timeout"

**Cause**: Deployment script takes longer than 1 hour (Azure limit for `az vm run-command invoke`).

**Solution**:
1. Optimize the deployment script (e.g., pre-warm Helm charts).
2. For longer deployments, use **SSH + nohup**:
   ```bash
   nohup /opt/deploy/deploy.sh ... > /tmp/deploy.log 2>&1 &
   ```

### Issue: kubectl commands fail on Jump VM

**Cause**: Jump VM's managed identity lacks permissions on AKS cluster.

**Solution**:
1. Verify RBAC role assignments exist:
   ```bash
   az role assignment list --assignee <JUMP_VM_PRINCIPAL_ID> --output table
   ```
2. Ensure role assignments include:
   - `Azure Kubernetes Service Cluster User Role` on AKS cluster
   - `Reader` on resource group

## Environment Variables Reference

| Variable | Source | Used For |
|---|---|---|
| `AZURE_SUBSCRIPTION_ID` | `TF_VAR_SUBSCRIPTION_ID` secret | AKS credential lookup |
| `ACR_NAME` | `TF_VAR_ACR_NAME` secret | ACR login |
| `ACR_LOGIN_SERVER` | Computed from ACR_NAME | Image registry URL |
| `AKS_CLUSTER_NAME` | `TF_VAR_AKS_CLUSTER_NAME` secret | AKS cluster reference |
| `RESOURCE_GROUP` | `TF_VAR_RESOURCE_GROUP_NAME` secret | Resource group reference |
| `IMAGE_TAG` | Commit SHA | Docker image tag |
| `JUMP_VM_NAME` | `JUMP_VM_NAME` secret (or derived) | Jump VM reference |

## Related Files

- `.github/workflows/deploy.yml` — Modified workflow (this file)
- `/opt/deploy/deploy.sh` — Deployment script on Jump VM
- `terraform/environments/dev/rbac.tf` — Role assignments for Jump VM
- `terraform/modules/vm/` — Jump VM module with managed identity
