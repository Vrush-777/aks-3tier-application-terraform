# GitHub Actions Workflow - YAML Changes Summary

## File: `.github/workflows/deploy.yml`

### What Changed

The `deploy` job was completely refactored to execute deployment on the Jump VM instead of directly from the GitHub-hosted runner.

### Key Changes

#### ✅ Preserved
- `detect-changes` job — unchanged
- `build-backend` job — unchanged (Docker build & push)
- `build-frontend` job — unchanged (Docker build & push)
- Environment variables for AZURE_SUBSCRIPTION_ID, ACR_NAME, AKS_CLUSTER_NAME, RESOURCE_GROUP
- Azure Login step with AZURE_CREDENTIALS secret

#### ❌ Removed
- `Get AKS Credentials` step — no longer needed (Jump VM handles this)
- `Setup Helm` step — runs on Jump VM instead
- `Add Helm Repositories` step — runs on Jump VM instead
- `Create Namespace` with kubectl — runs on Jump VM instead
- `Helm Dry-Run` step — runs on Jump VM instead
- `Helm Upgrade/Install` step — runs on Jump VM instead
- `Wait for Rollout` with kubectl — runs on Jump VM instead
- `Get Deployment Info` with kubectl — runs on Jump VM instead
- `Run Smoke Tests` with kubectl — runs on Jump VM instead
- `Create Rollback Secret` with kubectl — runs on Jump VM instead
- `Store Deployment Artifacts` step

#### ✅ Added
- `Deploy via Jump VM Run Command` — uses `az vm run-command invoke`
- `Check Deployment Status` — remote status check via Jump VM
- `Store Deployment Summary` — artifact with deployment metadata

---

## Deploy Job - Before vs. After

### BEFORE (Direct Execution from GitHub Runner)
```yaml
deploy:
  name: Deploy to AKS via Helm
  runs-on: ubuntu-latest
  steps:
    - name: Checkout code
      ...
    
    - name: Azure Login
      ...
    
    - name: Get AKS Credentials          # ❌ REMOVED
      run: |
        az aks get-credentials ...
    
    - name: Setup Helm                   # ❌ REMOVED
      ...
    
    - name: Helm Upgrade/Install         # ❌ REMOVED
      run: |
        helm upgrade --install ...
    
    - name: kubectl rollout status       # ❌ REMOVED
      run: |
        kubectl rollout status ...
```

### AFTER (Jump VM Execution)
```yaml
deploy:
  name: Deploy to Private AKS via Jump VM
  runs-on: ubuntu-latest
  steps:
    - name: Checkout code
      ...
    
    - name: Azure Login
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}
    
    - name: Deploy via Jump VM Run Command      # ✅ NEW
      id: deploy-jump-vm
      run: |
        IMAGE_TAG="${{ github.event.workflow_run.head_sha }}"
        JUMP_VM_NAME="${{ secrets.JUMP_VM_NAME || ... }}"
        
        az vm run-command invoke \
          --resource-group "${{ env.RESOURCE_GROUP }}" \
          --name "$JUMP_VM_NAME" \
          --command-id RunShellScript \
          --scripts "/opt/deploy/deploy.sh --resource-group ... --cluster ... --tag ... --registry ..." \
          --query 'value[0].message' \
          --output text
    
    - name: Check Deployment Status            # ✅ NEW
      continue-on-error: true
      run: |
        JUMP_VM_NAME="${{ secrets.JUMP_VM_NAME || ... }}"
        
        az vm run-command invoke \
          --resource-group "${{ env.RESOURCE_GROUP }}" \
          --name "$JUMP_VM_NAME" \
          --command-id RunShellScript \
          --scripts "kubectl get deployments ... && kubectl get pods ..." \
          --query 'value[0].message' \
          --output text
    
    - name: Store Deployment Summary           # ✅ NEW
      run: |
        cat > deployment-summary.txt <<EOF
        ...deployment metadata...
        EOF
```

---

## New Deployment Command

### GitHub Actions invokes:

```bash
az vm run-command invoke \
  --resource-group <RESOURCE_GROUP> \
  --name <JUMP_VM_NAME> \
  --command-id RunShellScript \
  --scripts "/opt/deploy/deploy.sh \
    --resource-group '<RESOURCE_GROUP>' \
    --cluster '<AKS_CLUSTER_NAME>' \
    --tag '<IMAGE_TAG>' \
    --registry '<ACR_LOGIN_SERVER>'"
```

### Which runs on Jump VM:

```bash
/opt/deploy/deploy.sh \
  --resource-group dev-rg \
  --cluster aks-dev \
  --tag abc1234567890... \
  --registry myacr.azurecr.io
```

### The script on Jump VM executes:

```bash
az aks get-credentials --resource-group dev-rg --name aks-dev
helm upgrade --install employee-management-system ... \
  --set backend.image.tag=abc1234567890... \
  --set registry.name=myacr.azurecr.io
kubectl rollout status deployment/ems-backend ...
```

---

## Environment Variables

### Existing (Preserved)
```yaml
env:
  AZURE_SUBSCRIPTION_ID: ${{ secrets.TF_VAR_SUBSCRIPTION_ID }}
  ACR_NAME: ${{ secrets.TF_VAR_ACR_NAME }}
  ACR_LOGIN_SERVER: ${{ secrets.TF_VAR_ACR_NAME }}.azurecr.io
  AKS_CLUSTER_NAME: ${{ secrets.TF_VAR_AKS_CLUSTER_NAME }}
  RESOURCE_GROUP: ${{ secrets.TF_VAR_RESOURCE_GROUP_NAME }}
  HELM_CHART_PATH: ./helm/employee-management-system
  DEPLOYMENT_NAMESPACE: employee-management
  DOCKER_BUILDKIT: 1
```

### New (Required Secrets)
```yaml
secrets:
  TF_VAR_ENVIRONMENT_PREFIX    # e.g., 'dev' (used to infer Jump VM name)
  JUMP_VM_NAME                 # Optional; defaults to ${TF_VAR_ENVIRONMENT_PREFIX}-jumpvm
```

---

## Execution Flow

```
GitHub Actions Runner
│
├─ Build Backend Docker image
├─ Push to ACR
│
├─ Build Frontend Docker image
├─ Push to ACR
│
└─ Deploy (NEW FLOW)
   │
   └─ Azure Login (AZURE_CREDENTIALS)
      │
      └─ az vm run-command invoke
         │
         ├─ Authenticate to Azure
         ├─ Connect to Jump VM
         ├─ Execute /opt/deploy/deploy.sh
         │
         └─ Jump VM
            │
            ├─ az aks get-credentials
            ├─ helm upgrade --install
            ├─ kubectl rollout status
            └─ kubectl get pods ...
               │
               └─ Private AKS Cluster ✓
```

---

## No Changes Required To

- Terraform configuration
- Docker image build steps
- ACR authentication
- GitHub Actions secrets (except for JUMP_VM_NAME if needed)
- Helm charts or values files
- Kubernetes manifests

---

## Deployment Parameters Passed to Jump VM

| Parameter | Source | Purpose |
|-----------|--------|---------|
| `--resource-group` | `RESOURCE_GROUP` env | `az aks get-credentials --resource-group <value>` |
| `--cluster` | `AKS_CLUSTER_NAME` env | `az aks get-credentials --name <value>` |
| `--tag` | `github.event.workflow_run.head_sha` | `--set backend.image.tag=<value>` |
| `--registry` | `ACR_LOGIN_SERVER` env | `--set registry.name=<value>` |

These are parsed in `/opt/deploy/deploy.sh` and used throughout the deployment process.
