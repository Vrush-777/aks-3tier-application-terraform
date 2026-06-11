# Private AKS Automated Deployment Implementation Guide

## 📋 Overview

This guide provides complete instructions for implementing a fully automated deployment solution for a private AKS cluster without requiring GitHub self-hosted runners or manual VM configuration.

### Architecture

```
GitHub Actions (Ubuntu Runner)
    ↓
    ├─ Build Docker Images
    ├─ Push to Azure Container Registry (ACR)
    └─ Invoke Azure VM Run Command
         ↓
    Jump VM (Private Subnet)
         ├─ System-Assigned Managed Identity
         ├─ Authenticate with az login --identity
         ├─ Retrieve AKS credentials
         ├─ Convert kubeconfig with kubelogin
         └─ Deploy with Helm
              ↓
         Private AKS Cluster
              ↓
         Employee Management System
```

## 🔧 Implementation Steps

### Step 1: Update Terraform Module - Jump VM

#### 1.1 Add Identity Variables
**File**: `terraform/modules/vm/variables-identity.tf`

This new file declares variables needed for managed identity and role assignments:
- `enable_managed_identity`: Enable System Assigned Managed Identity
- `aks_cluster_id`: AKS resource ID for role assignments
- `acr_id`: Container Registry resource ID
- `resource_group_id`: Resource group resource ID

#### 1.2 Update VM Resource with Identity
**File**: `terraform/modules/vm/main.tf`

Add the identity block to the `azurerm_linux_virtual_machine` resource:

```hcl
identity {
  type = "SystemAssigned"
}
```

**Why**: System-assigned identity automatically creates and manages an identity for the VM without additional setup.

#### 1.3 Create Role Assignments
**File**: `terraform/modules/vm/main-identity.tf`

This new file defines three role assignments:

**1. AKS Cluster User Role**
- Allows Jump VM to authenticate to the AKS cluster using managed identity
- Enables kubelogin to work seamlessly
- No public API exposure required

**2. Reader Role on Resource Group**
- Allows Jump VM to query resource group resources
- Required for getting AKS cluster details via `az aks get-credentials`

**3. AcrPull Role on ACR**
- Allows Jump VM (and deployed applications) to pull images from registry
- Secure alternative to admin credentials

#### 1.4 Add Deployment Outputs
**File**: `terraform/modules/vm/outputs-identity.tf`

New outputs provide information for deployment automation:
- `vm_name`: Jump VM name (for Azure Run Command)
- `vm_principal_id`: Managed identity principal ID (for role assignments)
- `resource_group_name`: Resource group name
- `vm_private_ip`: Private IP (for internal reference)
- `vm_public_ip`: Public IP (for SSH access during troubleshooting)

### Step 2: Configure Environment-Specific Settings

#### 2.1 Add Variables to Dev Environment
**File**: `terraform/environments/dev/variables-jumpvm.tf`

This new file adds Jump VM-specific variables:
- `jumpvm_admin_username`: SSH username (default: azureuser)
- `jumpvm_ssh_public_key`: Your SSH public key (from GitHub Secrets)
- `jumpvm_vm_size`: VM SKU (default: Standard_B2s for dev)
- `jumpvm_enable`: Toggle for enabling Jump VM

#### 2.2 Wire Up Module in Main Configuration
**File**: `terraform/environments/dev/main.tf`

Add the jump_vm module call (see `jump-vm-module-config.md`):

```hcl
module "jump_vm" {
  source = "../../modules/vm"
  
  resource_group_name     = module.resource_group.resource_group_name
  location                = module.resource_group.location
  # ... other configuration ...
  
  enable_managed_identity = true
  aks_cluster_id         = module.aks.aks_id
  acr_id                 = module.acr.acr_id
  resource_group_id      = module.resource_group.resource_group_id
  
  depends_on = [module.aks, module.acr, module.network]
}
```

#### 2.3 Add Outputs for GitHub Actions
**File**: `terraform/environments/dev/outputs-jumpvm.tf`

This new file exposes Jump VM information:
- `JUMP_VM_NAME`: For Azure Run Command invocation
- `jumpvm_principal_id`: For reference
- `deployment_config`: Aggregated configuration for deployment tools
- `infrastructure_summary`: Complete infrastructure overview

### Step 3: Cloud-Init Setup Script

#### 3.1 Deploy Cloud-Init Script
**File**: `terraform/scripts/jumpvm-cloud-init.yaml`

This comprehensive cloud-init configuration automatically:

**Tools Installation**:
- Azure CLI (with managed identity authentication)
- kubectl (Kubernetes CLI)
- kubelogin (Managed identity-aware kubectl auth plugin)
- Helm v3 (Kubernetes package manager)
- jq (JSON processor)
- unzip (Archive tool)

**Deployment Script Creation**:
- Creates `/opt/deploy/deploy.sh` with full Helm deployment logic
- Implements managed identity authentication
- Handles kubeconfig conversion via kubelogin
- Includes logging and error handling
- Verifies cluster connectivity and deployment status

**Helper Features**:
- Systemd service file for easy script invocation
- Environment profile for convenient CLI usage
- Helper scripts for common operations
- Installation verification

**Key Features of deploy.sh**:

```bash
# Authenticate using managed identity (no credentials needed!)
az login --identity --allow-no-subscriptions

# Get AKS credentials
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME

# Convert kubeconfig for managed identity authentication
kubelogin convert-kubeconfig -l azurecli

# Deploy with Helm (with parameters passed from GitHub Actions)
helm upgrade --install $HELM_RELEASE \
  $HELM_CHART_PATH \
  --namespace $HELM_NAMESPACE \
  --set image.tag="$IMAGE_TAG" \
  --wait --timeout 10m
```

### Step 4: GitHub Actions Workflow

#### 4.1 New Workflow File
**File**: `.github/workflows/deploy-private-aks.yml`

**Workflow Triggers**:
- Completes when Terraform workflow finishes
- Manual trigger via `workflow_dispatch`

**Job 1: detect-changes**
- Uses `dorny/paths-filter` to detect code changes
- Outputs flags for conditional job execution
- Prevents unnecessary builds

**Job 2: build-backend**
- Builds JAR with Maven
- Builds Docker image with git SHA tag
- Pushes to ACR via service principal auth
- Caches Docker layers

**Job 3: build-frontend**
- Builds with Node.js/npm
- Builds Docker image with git SHA tag
- Pushes to ACR via service principal auth
- Caches npm dependencies

**Job 4: deploy-to-aks**
- Retrieves Jump VM name from secrets
- Gets image tags from build jobs
- **Key Step**: Uses `az vm run-command invoke` to execute deployment script on Jump VM

```yaml
az vm run-command invoke \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${JUMP_VM_NAME}" \
  --command-id RunShellScript \
  --scripts "/opt/deploy/deploy.sh ${RG} ${CLUSTER} ${TAG} ${ACR}"
```

**Job 5: validate-deployment**
- Runs smoke tests
- Verifies application accessibility

#### 4.2 GitHub Secrets Required

Add these secrets to your GitHub repository:

```yaml
AZURE_CREDENTIALS:      # Service Principal credentials (JSON)
TF_VAR_SUBSCRIPTION_ID: # Azure Subscription ID
TF_VAR_TENANT_ID:       # Azure Tenant ID
TF_VAR_ACR_NAME:        # ACR name (without .azurecr.io)
TF_VAR_AKS_CLUSTER_NAME: # AKS cluster name
TF_VAR_RESOURCE_GROUP_NAME: # Resource group name
JUMP_VM_NAME:            # Jump VM name (output from Terraform)
jumpvm_ssh_public_key:  # Your SSH public key
```

### Step 5: Update terraform.tfvars

**File**: `terraform/environments/dev/terraform.tfvars`

Add or update:

```hcl
jumpvm_admin_username = "azureuser"
jumpvm_vm_size        = "Standard_B2s"  # For development
# jumpvm_ssh_public_key is provided via GitHub Actions secrets
```

## 🚀 Deployment Workflow

### Initial Setup (One-Time)

```bash
# 1. Set up GitHub secrets
# Go to Settings → Secrets and Variables → Actions
# Add all required secrets listed above

# 2. Deploy Terraform infrastructure
cd terraform/environments/dev
terraform init
terraform plan
terraform apply

# 3. Capture outputs
terraform output -json > deployment_config.json

# 4. Update GitHub Secrets with outputs
# Specifically: JUMP_VM_NAME (and others as needed)
```

### Automated Deployment Flow

```
Developer Push → GitHub Actions Triggered
  ↓
Terraform Workflow (Infrastructure)
  ↓
Deploy Workflow (Build + Deploy)
  ├─ Build Backend Docker image
  ├─ Push to ACR
  ├─ Build Frontend Docker image
  ├─ Push to ACR
  ├─ Invoke Jump VM via Run Command
  │   ├─ Authenticate with Managed Identity
  │   ├─ Get AKS credentials
  │   ├─ Configure kubelogin
  │   └─ Execute Helm deployment
  ├─ Verify deployment
  └─ Smoke tests
```

## 🔐 Security Features

### Managed Identity Benefits

✅ **No Credentials in Code**
- No service principal credentials in VM
- No secrets in environment variables
- No password storage required

✅ **Principle of Least Privilege**
- Granular role assignments
- Reader role (not Owner)
- AcrPull role (not admin)

✅ **Automatic Token Management**
- Azure CLI automatically handles tokens
- kubelogin seamlessly integrates
- No token refresh needed in scripts

✅ **Secure Private Access**
- Private AKS cluster (no public API)
- Jump VM acts as private gateway
- All communication within VNet

### Role Assignments

| Role | Resource | Purpose |
|------|----------|---------|
| Azure Kubernetes Service Cluster User | AKS Cluster | Authenticate to cluster |
| Reader | Resource Group | Query cluster information |
| AcrPull | Container Registry | Pull deployment images |

## 🛠️ Troubleshooting

### Check Jump VM Status

```bash
# SSH into Jump VM
ssh azureuser@<public_ip>

# Verify managed identity
az login --identity
az account list

# Test AKS connectivity
az aks get-credentials --resource-group <rg> --name <cluster>
kubectl cluster-info

# Check deployment logs
tail -f /opt/deploy/logs/deploy-*.log
```

### Common Issues

**Issue**: "kubelogin: command not found"
**Solution**: Re-run cloud-init manually or check installation: `kubelogin --version`

**Issue**: "failed to get credentials"
**Solution**: Verify Reader role on resource group: `az role assignment list --resource-group <rg>`

**Issue**: "authentication failed with managed identity"
**Solution**: Verify System-Assigned Identity is enabled: `az vm identity show -g <rg> -n <vm-name>`

## 📊 Monitoring & Logging

### Deployment Logs

**On Jump VM**:
```bash
tail -f /opt/deploy/logs/deploy-*.log
```

**In GitHub Actions**:
- Raw workflow logs available in Actions tab
- Real-time logs visible during execution
- Archived for 30 days by default

### Health Checks

```bash
# Check pod status
kubectl get pods -n employee-management

# Check service endpoints
kubectl get svc -n employee-management

# View application logs
kubectl logs -f deployment/ems-backend -n employee-management
```

## 📋 Checklist for Deployment

- [ ] Terraform modules updated with identity configuration
- [ ] Cloud-init script deployed to correct path
- [ ] GitHub Actions workflow created
- [ ] GitHub Secrets configured
- [ ] terraform.tfvars updated with Jump VM settings
- [ ] Terraform apply executed successfully
- [ ] Jump VM outputs captured
- [ ] Test deployment workflow manually triggered
- [ ] Smoke tests passing
- [ ] Production ready!

## 🎯 Next Steps

1. **Enable Helm Chart Version Management**: Add semantic versioning to Helm charts
2. **Implement GitOps**: Use Flux/ArgoCD for declarative deployments
3. **Add Monitoring**: Integrate Application Insights for application monitoring
4. **Multi-Region**: Extend setup for disaster recovery with multiple AKS clusters
5. **Policy Enforcement**: Add Azure Policy for cluster governance

## 📚 Additional Resources

- [Azure Managed Identities Documentation](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/)
- [kubelogin Documentation](https://github.com/Azure/kubelogin)
- [Azure VM Run Command](https://learn.microsoft.com/en-us/azure/virtual-machines/run-command-overview)
- [Private AKS Cluster Configuration](https://learn.microsoft.com/en-us/azure/aks/private-clusters)
