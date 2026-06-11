# Deploy Job - Complete YAML Reference

## Modified `.github/workflows/deploy.yml` - Deploy Job

```yaml
  deploy:
    name: Deploy to Private AKS via Jump VM
    runs-on: ubuntu-latest
    needs: [build-backend, build-frontend]
    if: github.event.workflow_run.conclusion == 'success'
    environment:
      name: dev

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          ref: ${{ github.event.workflow_run.head_branch }}

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Deploy via Jump VM Run Command
        id: deploy-jump-vm
        run: |
          # Set the image tag from the commit SHA
          IMAGE_TAG="${{ github.event.workflow_run.head_sha }}"
          
          # Get the Jump VM name (inferred from naming convention)
          # For production, store Jump VM name as a {{ secrets.JUMP_VM_NAME }}
          JUMP_VM_NAME="${{ secrets.JUMP_VM_NAME || format('{0}-jumpvm', secrets.TF_VAR_ENVIRONMENT_PREFIX) }}"
          
          # Build the deployment command to execute on Jump VM
          DEPLOY_COMMAND="/opt/deploy/deploy.sh"
          DEPLOY_PARAMS="--resource-group '${{ env.RESOURCE_GROUP }}' --cluster '${{ env.AKS_CLUSTER_NAME }}' --tag '$IMAGE_TAG' --registry '${{ env.ACR_LOGIN_SERVER }}'"
          
          echo "Deploying to AKS via Jump VM: $JUMP_VM_NAME"
          echo "Deployment script: $DEPLOY_COMMAND"
          echo "Parameters: $DEPLOY_PARAMS"
          
          # Invoke the deployment script on the Jump VM
          az vm run-command invoke \
            --resource-group "${{ env.RESOURCE_GROUP }}" \
            --name "$JUMP_VM_NAME" \
            --command-id RunShellScript \
            --scripts "$DEPLOY_COMMAND $DEPLOY_PARAMS" \
            --query 'value[0].message' \
            --output text
          
          echo "Deploy command exit code: $?"
          
      - name: Check Deployment Status
        continue-on-error: true
        run: |
          # Get Jump VM name for subsequent commands
          JUMP_VM_NAME="${{ secrets.JUMP_VM_NAME || format('{0}-jumpvm', secrets.TF_VAR_ENVIRONMENT_PREFIX) }}"
          
          # Query deployment status from the Jump VM
          az vm run-command invoke \
            --resource-group "${{ env.RESOURCE_GROUP }}" \
            --name "$JUMP_VM_NAME" \
            --command-id RunShellScript \
            --scripts "kubectl get deployments -n employee-management; kubectl get pods -n employee-management; kubectl get svc -n employee-management" \
            --query 'value[0].message' \
            --output text
            
      - name: Store Deployment Summary
        if: always()
        run: |
          cat > deployment-summary.txt <<EOF
          Deployment Workflow Summary
          ===========================
          Git Commit: ${{ github.event.workflow_run.head_sha }}
          Git Branch: ${{ github.event.workflow_run.head_branch }}
          Image Tag: ${{ github.event.workflow_run.head_sha }}
          AKS Cluster: ${{ env.AKS_CLUSTER_NAME }}
          Resource Group: ${{ env.RESOURCE_GROUP }}
          ACR Registry: ${{ env.ACR_LOGIN_SERVER }}
          Deployment Method: Jump VM via az vm run-command invoke
          Workflow Run ID: ${{ github.run_id }}
          Timestamp: $(date -u +'%Y-%m-%dT%H:%M:%SZ')
          EOF
          cat deployment-summary.txt
          
      - name: Upload Deployment Summary
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: deployment-summary-${{ github.run_id }}
          path: deployment-summary.txt
```

---

## Full Workflow Structure (3 Jobs Preserved)

```yaml
name: Build and Deploy to AKS

on:
  workflow_run:
    workflows:
      - Terraform Infrastructure Pipeline
    types:
      - completed

env:
  AZURE_SUBSCRIPTION_ID: ${{ secrets.TF_VAR_SUBSCRIPTION_ID }}
  ACR_NAME: ${{ secrets.TF_VAR_ACR_NAME }}
  ACR_LOGIN_SERVER: ${{ secrets.TF_VAR_ACR_NAME }}.azurecr.io
  AKS_CLUSTER_NAME: ${{ secrets.TF_VAR_AKS_CLUSTER_NAME }}
  RESOURCE_GROUP: ${{ secrets.TF_VAR_RESOURCE_GROUP_NAME }}
  HELM_CHART_PATH: ./helm/employee-management-system
  DEPLOYMENT_NAMESPACE: employee-management
  DOCKER_BUILDKIT: 1

jobs:
  detect-changes:           # ✅ UNCHANGED
    # ... (detect file changes)
  
  build-backend:            # ✅ UNCHANGED
    # ... (build and push backend Docker image)
  
  build-frontend:           # ✅ UNCHANGED
    # ... (build and push frontend Docker image)
  
  deploy:                   # 🔄 COMPLETELY REFACTORED
    name: Deploy to Private AKS via Jump VM
    runs-on: ubuntu-latest
    needs: [build-backend, build-frontend]
    if: github.event.workflow_run.conclusion == 'success'
    environment:
      name: dev
    steps:
      # ... (see full deploy job above)
```

---

## Key Command Breakdown

### Step 1: Prepare Parameters

```bash
IMAGE_TAG="${{ github.event.workflow_run.head_sha }}"
# Result: 5f3c9e2a1b4d6f8e9c0a1b2c3d4e5f6a7b8c9d0e

JUMP_VM_NAME="${{ secrets.JUMP_VM_NAME || format('{0}-jumpvm', secrets.TF_VAR_ENVIRONMENT_PREFIX) }}"
# Result: dev-jumpvm (or explicit name if JUMP_VM_NAME secret set)

DEPLOY_COMMAND="/opt/deploy/deploy.sh"

DEPLOY_PARAMS="--resource-group 'rg-dev' --cluster 'aks-dev' --tag '5f3c9e2a...' --registry 'myacr.azurecr.io'"
```

### Step 2: Execute on Jump VM

```bash
az vm run-command invoke \
  --resource-group "rg-dev" \
  --name "dev-jumpvm" \
  --command-id RunShellScript \
  --scripts "/opt/deploy/deploy.sh --resource-group 'rg-dev' --cluster 'aks-dev' --tag '5f3c9e2a...' --registry 'myacr.azurecr.io'" \
  --query 'value[0].message' \
  --output text
```

### Step 3: What Runs on Jump VM

```bash
#!/bin/bash
# Executed on Jump VM

# Parse parameters
RESOURCE_GROUP="rg-dev"
AKS_CLUSTER_NAME="aks-dev"
IMAGE_TAG="5f3c9e2a..."
ACR_LOGIN_SERVER="myacr.azurecr.io"

# Get AKS credentials using managed identity
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER_NAME"

# Deploy via Helm with new image tags
helm upgrade --install employee-management-system \
  ./helm/employee-management-system \
  --namespace employee-management \
  --set backend.image.tag="5f3c9e2a..." \
  --set frontend.image.tag="5f3c9e2a..." \
  --set registry.name="myacr.azurecr.io" \
  --wait --timeout 10m --atomic

# Wait for rollout
kubectl rollout status deployment/ems-backend -n employee-management --timeout=5m
```

---

## Status Check Command

```bash
az vm run-command invoke \
  --resource-group "${{ env.RESOURCE_GROUP }}" \
  --name "dev-jumpvm" \
  --command-id RunShellScript \
  --scripts "kubectl get deployments -n employee-management; kubectl get pods -n employee-management; kubectl get svc -n employee-management" \
  --query 'value[0].message' \
  --output text
```

Outputs pod status and services directly to workflow logs.

---

## Expected Workflow Execution

```
┌─────────────────────────────────────────┐
│ detect-changes (30 sec)                │
│ Scan for file changes                  │
└──────────────┬──────────────────────────┘
               │
    ┌──────────┴──────────┐
    │                     │
    ▼                     ▼
┌────────────────┐  ┌────────────────┐
│ build-backend  │  │build-frontend  │
│ (5-10 min)     │  │ (5-10 min)     │
└────────────────┘  └────────────────┘
    │                     │
    └──────────┬──────────┘
               │ (both succeed)
               ▼
┌──────────────────────────────────────────┐
│ deploy (5-15 min)                       │
│ ├─ Checkout code (1 sec)               │
│ ├─ Azure Login (10 sec)                │
│ ├─ Deploy via Jump VM (5-10 min)       │
│ │  └─ az vm run-command invoke         │
│ │     └─ /opt/deploy/deploy.sh         │
│ │        └─ helm upgrade + k8s deploy  │
│ ├─ Check Status (30 sec)               │
│ └─ Store Summary (5 sec)               │
└──────────────────────────────────────────┘
               │
               ▼
          ✅ SUCCESS
          
Total: ~15-35 minutes
```

---

## Artifacts Generated

```
deployment-summary-<RUN_ID>/
└── deployment-summary.txt
    ├── Git Commit SHA
    ├── Git Branch
    ├── Image Tag
    ├── AKS Cluster
    ├── Resource Group
    ├── ACR Registry
    ├── Deployment Method
    ├── Workflow Run ID
    └── Timestamp
```

---

## Workflow Logs Output

```
Deploying to AKS via Jump VM: dev-jumpvm
Deployment script: /opt/deploy/deploy.sh
Parameters: --resource-group 'rg-dev' --cluster 'aks-dev' --tag 'abc123...' --registry 'myacr.azurecr.io'

[Jump VM stdout]
==========================================
Private AKS Deployment
==========================================
Resource Group: rg-dev
AKS Cluster: aks-dev
Image Tag: abc123...
ACR Registry: myacr.azurecr.io
...
Deployments:
NAME            READY   UP-TO-DATE   AVAILABLE
ems-backend     1/1     1            1
ems-frontend    1/1     1            1
...
Deployment completed successfully!
==========================================

Deploy command exit code: 0
```

---

## Required GitHub Secrets

```yaml
AZURE_CREDENTIALS:
  - clientId
  - clientSecret
  - subscriptionId
  - tenantId

TF_VAR_SUBSCRIPTION_ID: "12345678-..."
TF_VAR_ACR_NAME: "myacr"
TF_VAR_AKS_CLUSTER_NAME: "aks-dev"
TF_VAR_RESOURCE_GROUP_NAME: "rg-dev"
TF_VAR_ENVIRONMENT_PREFIX: "dev"
JUMP_VM_NAME: "dev-jumpvm" (optional)
```
