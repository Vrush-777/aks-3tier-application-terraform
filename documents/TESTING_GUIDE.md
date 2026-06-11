# Testing & Troubleshooting Guide

## 🧪 Pre-Deployment Testing

### 1. Terraform Validation

```bash
# Navigate to environment
cd terraform/environments/dev

# Initialize (if not done)
terraform init

# Validate configuration
terraform validate

# Plan deployment (dry-run)
terraform plan -out=tfplan

# Review the plan and verify:
# - Jump VM will be created
# - Role assignments will be created
# - Managed identity will be assigned
```

### 2. Cloud-Init Script Validation

```bash
# Check YAML syntax
python3 -m yaml terraform/scripts/jumpvm-cloud-init.yaml

# Verify critical sections
grep -n "az login --identity" terraform/scripts/jumpvm-cloud-init.yaml
grep -n "kubelogin convert-kubeconfig" terraform/scripts/jumpvm-cloud-init.yaml
grep -n "helm upgrade" terraform/scripts/jumpvm-cloud-init.yaml
```

### 3. Terraform Code Syntax

```bash
# Check main.tf for identity block
grep -A 5 "identity {" terraform/modules/vm/main.tf

# Verify role assignments are defined
grep -l "azurerm_role_assignment" terraform/modules/vm/*.tf

# Check module call in environments
grep -A 15 "module.*jump_vm" terraform/environments/dev/main.tf
```

## 🚀 Deployment Testing

### Test 1: Create Infrastructure

```bash
cd terraform/environments/dev

# Deploy
terraform apply tfplan

# Capture outputs
terraform output -json > deployment_output.json

# Verify key outputs
terraform output jumpvm_name
terraform output jumpvm_principal_id
terraform output jumpvm_public_ip
```

### Test 2: Verify Managed Identity

```bash
# After deployment, check managed identity
RESOURCE_GROUP=$(terraform output -raw resource_group_name)
JUMPVM_NAME=$(terraform output -raw jumpvm_name)

# Check identity exists
az vm identity show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$JUMPVM_NAME" \
  --query systemAssignedIdentity

# Check principal ID
PRINCIPAL_ID=$(az vm identity show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$JUMPVM_NAME" \
  --query principalId -o tsv)

echo "Principal ID: $PRINCIPAL_ID"
```

### Test 3: Verify Role Assignments

```bash
# Check all role assignments for the managed identity
az role assignment list \
  --assignee "$PRINCIPAL_ID" \
  --output table

# Specifically check for:
# 1. "Azure Kubernetes Service Cluster User Role" on AKS cluster
# 2. "Reader" on resource group
# 3. "AcrPull" on ACR
```

### Test 4: SSH into Jump VM

```bash
# Get public IP
JUMPVM_PUBLIC_IP=$(terraform output -raw jumpvm_public_ip)

# Wait for VM to be ready (cloud-init completion takes 3-5 minutes)
echo "Waiting for Jump VM initialization..."
sleep 300

# SSH into Jump VM
ssh -i your-private-key azureuser@$JUMPVM_PUBLIC_IP

# Once connected, verify tools are installed
az --version
kubectl version --client
kubelogin --version
helm version
jq --version
```

### Test 5: Test Managed Identity Authentication

```bash
# On the Jump VM:

# 1. Authenticate with managed identity
az login --identity

# 2. Verify account
az account show

# 3. Verify access to subscription
az account list --output table

# 4. Verify role assignments
PRINCIPAL_ID=$(az ad sp show --id $(az account show -o tsv --query id) -o tsv --query id)
az role assignment list --assignee $PRINCIPAL_ID --output table
```

### Test 6: Get AKS Credentials

```bash
# On the Jump VM:

# Set variables
RESOURCE_GROUP="your-resource-group"
AKS_CLUSTER="your-aks-cluster"

# Get credentials
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_CLUSTER" \
  --overwrite-existing

# Verify kubeconfig
cat ~/.kube/config | head -20
```

### Test 7: Configure kubelogin

```bash
# On the Jump VM:

# Convert kubeconfig for managed identity auth
kubelogin convert-kubeconfig -l azurecli

# Verify kubelogin is configured
kubectl config view | grep "exec"
```

### Test 8: Test Cluster Connectivity

```bash
# On the Jump VM:

# Get cluster info
kubectl cluster-info

# Get nodes
kubectl get nodes

# Get all resources
kubectl get all --all-namespaces | head -20
```

### Test 9: Manual Deployment Script Test

```bash
# On the Jump VM:

# Create test Helm chart location (or copy your actual chart)
mkdir -p /opt/deploy/helm-chart

# Run deployment script manually
/opt/deploy/deploy.sh "your-rg" "your-cluster" "v1.0.0" "myacr.azurecr.io"

# Check logs
tail -f /opt/deploy/logs/deploy-*.log
```

## 🔍 Detailed Troubleshooting

### Issue: "authentication failed with managed identity"

**Diagnosis**:
```bash
# SSH into Jump VM
ssh azureuser@<public-ip>

# Try to authenticate
az login --identity

# Check error details
az login --identity --debug
```

**Solutions**:

1. **Verify Identity Exists**:
```bash
az vm identity show -g <rg> -n <vm-name>
```
If empty, the identity block wasn't added to the VM resource.

2. **Check Role Assignments**:
```bash
PRINCIPAL_ID=$(az vm identity show -g <rg> -n <vm-name> -q principalId -o tsv)
az role assignment list --assignee $PRINCIPAL_ID
```
If no results, role assignments weren't created.

3. **Verify Subscription Access**:
```bash
# On Jump VM
az account list
az account set --subscription <subscription-id>
```

### Issue: "kubelogin: command not found"

**Solutions**:

1. **Check Installation**:
```bash
which kubelogin
kubelogin --version
```

2. **Install Manually**:
```bash
# SSH into Jump VM
ssh azureuser@<public-ip>

# Install kubelogin manually
curl -LO https://github.com/Azure/kubelogin/releases/download/v0.0.37/kubelogin-linux-amd64.zip
unzip -q kubelogin-linux-amd64.zip
sudo mv bin/linux_amd64/kubelogin /usr/local/bin/
kubelogin --version
```

3. **Re-run Cloud-Init** (last resort):
```bash
# View cloud-init logs
sudo cloud-init status --format json
sudo cat /var/log/cloud-init-output.log | tail -100
```

### Issue: "failed to get AKS credentials"

**Diagnosis**:
```bash
# On Jump VM
az aks get-credentials \
  --resource-group <rg> \
  --name <cluster> \
  --debug

# Verify Reader role
az role assignment list \
  --assignee $(az vm identity show -g <rg> -n <vm-name> -q principalId -o tsv) \
  --output table
```

**Solutions**:

1. **Verify Reader Role**:
```bash
# From your local machine
az role assignment list \
  --resource-group <rg> \
  --output table
```

2. **Manually Assign Role** (if missing):
```bash
az role assignment create \
  --role "Reader" \
  --assignee <principal-id> \
  --resource-group <rg>
```

### Issue: "Failed to connect to cluster"

**Diagnosis**:
```bash
# On Jump VM
kubectl cluster-info --context=<context>
kubectl cluster-info dump --output-directory=./dump
```

**Solutions**:

1. **Check Private Endpoint Connectivity**:
```bash
# Ensure Jump VM is in same VNet as AKS
az vm show -g <rg> -n <vm-name> --query networkProfile.networkInterfaces[0].id

# Check NSG rules
az network nsg show -g <rg> -n <nsg-name>
```

2. **Verify kubelogin Configuration**:
```bash
kubectl config view | grep -A 5 "exec"
kubelogin convert-kubeconfig -l azurecli --force
```

### Issue: "Helm deployment timeout"

**Diagnosis**:
```bash
# SSH into Jump VM
ssh azureuser@<public-ip>

# Check Helm chart location
ls -la /opt/deploy/helm-chart/

# Check Helm releases
helm list -A

# Check deployment status
kubectl get deployment -A
kubectl describe deployment ems-backend -n employee-management
```

**Solutions**:

1. **Verify Helm Chart**:
```bash
# Chart structure should be:
# /opt/deploy/helm-chart/
# ├── Chart.yaml
# ├── values.yaml
# └── templates/

helm template ems /opt/deploy/helm-chart
```

2. **Check Pod Logs**:
```bash
kubectl logs pod/<pod-name> -n employee-management
kubectl describe pod/<pod-name> -n employee-management
```

3. **Check Image Pull**:
```bash
kubectl get events -n employee-management --sort-by='.lastTimestamp'
```

## 📊 Monitoring & Logging

### View Cloud-Init Logs on Jump VM

```bash
# SSH into Jump VM
ssh azureuser@<public-ip>

# View cloud-init output
sudo cat /var/log/cloud-init-output.log

# Check cloud-init status
cloud-init status

# View specific service logs
journalctl -xe
```

### View Deployment Script Logs

```bash
# SSH into Jump VM
ssh azureuser@<public-ip>

# Check logs directory
ls -la /opt/deploy/logs/

# View latest deployment log
tail -f /opt/deploy/logs/deploy-*.log

# View all deployment logs
cat /opt/deploy/logs/deploy-*.log | grep -E "✓|✗|ERROR"
```

### View Azure VM Run Command Logs

```bash
# From your local machine with Azure CLI

# Get last 10 run commands
az vm run-command list \
  --resource-group <rg> \
  --vm-name <vm-name> \
  --query "[].[id,name,provisioningState]" \
  --output table

# Get details of specific run command
az vm run-command show \
  --resource-group <rg> \
  --vm-name <vm-name> \
  --instance-view \
  --command-id RunShellScript
```

### View GitHub Actions Logs

1. Go to: **Actions** tab in GitHub repository
2. Select **Deploy** workflow
3. Click on specific run
4. Expand each job to see detailed logs
5. Check for `deploy-to-aks` job specifically

## ✅ Health Checks

### Pre-Deployment Checklist

```bash
# File verification
[ -f terraform/modules/vm/main-identity.tf ] && echo "✓ Identity module" || echo "✗ Identity module"
[ -f terraform/scripts/jumpvm-cloud-init.yaml ] && echo "✓ Cloud-init" || echo "✗ Cloud-init"
[ -f .github/workflows/deploy-private-aks.yml ] && echo "✓ Workflow" || echo "✗ Workflow"

# Terraform validation
terraform -chdir=terraform/environments/dev validate && echo "✓ Terraform valid" || echo "✗ Terraform invalid"
```

### Post-Deployment Checklist

```bash
# Jump VM status
JUMPVM_NAME=$(terraform -chdir=terraform/environments/dev output -raw jumpvm_name)
RG=$(terraform -chdir=terraform/environments/dev output -raw resource_group_name)

az vm get-instance-view -g $RG -n $JUMPVM_NAME -q "instanceView.statuses[1].displayStatus"

# Identity status
az vm identity show -g $RG -n $JUMPVM_NAME

# Role assignments
PRINCIPAL_ID=$(az vm identity show -g $RG -n $JUMPVM_NAME -q principalId -o tsv)
az role assignment list --assignee $PRINCIPAL_ID --output table
```

### Connectivity Check Script

```bash
#!/bin/bash

set -e

echo "🔍 Running connectivity checks..."
echo ""

# Get values
RG="${1:-}"
CLUSTER="${2:-}"
VM_NAME="${3:-}"

if [ -z "$RG" ] || [ -z "$CLUSTER" ] || [ -z "$VM_NAME" ]; then
    echo "Usage: $0 <resource-group> <aks-cluster> <vm-name>"
    exit 1
fi

# Check 1: VM Status
echo -n "Checking VM status... "
STATUS=$(az vm get-instance-view -g "$RG" -n "$VM_NAME" -q "instanceView.statuses[1].displayStatus" -o tsv)
if [[ "$STATUS" == "VM running" ]]; then
    echo "✓"
else
    echo "✗ ($STATUS)"
    exit 1
fi

# Check 2: Managed Identity
echo -n "Checking Managed Identity... "
if az vm identity show -g "$RG" -n "$VM_NAME" > /dev/null; then
    echo "✓"
else
    echo "✗"
    exit 1
fi

# Check 3: Role Assignments
echo -n "Checking Role Assignments... "
PRINCIPAL_ID=$(az vm identity show -g "$RG" -n "$VM_NAME" -q principalId -o tsv)
ROLE_COUNT=$(az role assignment list --assignee "$PRINCIPAL_ID" --query "length" -o tsv)
if [ "$ROLE_COUNT" -ge 3 ]; then
    echo "✓ ($ROLE_COUNT roles)"
else
    echo "✗ (only $ROLE_COUNT roles, expected 3)"
    exit 1
fi

# Check 4: AKS Cluster Status
echo -n "Checking AKS Cluster Status... "
CLUSTER_STATUS=$(az aks show -g "$RG" -n "$CLUSTER" -q "powerState.code" -o tsv)
if [[ "$CLUSTER_STATUS" == "Running" ]]; then
    echo "✓"
else
    echo "✗ ($CLUSTER_STATUS)"
    exit 1
fi

echo ""
echo "✓ All connectivity checks passed!"
```

## 📝 Logging Best Practices

### Enable Debug Logging

```bash
# In GitHub Actions (add to deploy.yml):
- name: Enable Debug
  run: |
    echo "::debug::Enabling debug logging"
    export TF_LOG=DEBUG
    export TF_LOG_PATH=./terraform-debug.log

# For Azure CLI:
az config set defaults.group=$RESOURCE_GROUP --debug > azure-debug.log 2>&1

# For kubectl:
export KUBECONFIG=$HOME/.kube/config
kubectl --v=6 get nodes
```

### Collect Diagnostics

```bash
#!/bin/bash

# Comprehensive diagnostics collector
mkdir -p diagnostics

# Terraform state
terraform -chdir=terraform/environments/dev show > diagnostics/tf-state.txt

# Azure resources
az resource list -g <rg> --output json > diagnostics/resources.json

# Kubernetes resources (via Jump VM)
kubectl get all --all-namespaces > diagnostics/k8s-all.txt
kubectl describe nodes > diagnostics/k8s-nodes.txt

# Logs
tar -czf diagnostics.tar.gz diagnostics/
```

---

**Use these tests and troubleshooting steps to validate and debug your private AKS deployment setup.**
