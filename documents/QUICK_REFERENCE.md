# Quick Implementation Reference

## 📁 File Changes Summary

### New Files to Create

```
terraform/
├── modules/
│   └── vm/
│       ├── variables-identity.tf          # NEW - Identity variables
│       ├── main-identity.tf               # NEW - Identity & role assignments
│       └── outputs-identity.tf            # NEW - Identity outputs
├── scripts/
│   └── jumpvm-cloud-init.yaml             # UPDATED - Complete cloud-init script
└── environments/
    └── dev/
        ├── variables-jumpvm.tf            # NEW - Jump VM variables
        ├── outputs-jumpvm.tf              # NEW - Jump VM outputs
        └── jump-vm-module-config.md       # NEW - Documentation

.github/
└── workflows/
    └── deploy-private-aks.yml             # NEW - Complete deployment workflow
```

### Modified Files

```
terraform/
└── modules/
    └── vm/
        └── main.tf                        # MODIFIED - Add identity block to VM

terraform/environments/dev/
└── main.tf                                # MODIFIED - Add jump_vm module call

terraform/environments/dev/
└── terraform.tfvars                       # MODIFIED - Add Jump VM variables
```

## 🔍 Key Code Sections

### 1. VM Identity Block (terraform/modules/vm/main.tf)

```hcl
identity {
  type = "SystemAssigned"
}
```

Insert after `custom_data` line in `azurerm_linux_virtual_machine` resource.

### 2. Module Call (terraform/environments/dev/main.tf)

```hcl
module "jump_vm" {
  source = "../../modules/vm"

  resource_group_name = module.resource_group.resource_group_name
  location            = module.resource_group.location
  prefix              = var.prefix
  admin_username      = var.jumpvm_admin_username
  ssh_public_key      = var.jumpvm_ssh_public_key
  subnet_id           = module.network.jumpvm_subnet_id
  nsg_id              = module.network.jumpvm_nsg_id
  vm_size             = var.jumpvm_vm_size

  enable_managed_identity = true
  aks_cluster_id         = module.aks.aks_id
  acr_id                 = module.acr.acr_id
  resource_group_id      = module.resource_group.resource_group_id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.prefix}-jumpvm"
      Role = "PrivateAKSDeploymentVM"
    }
  )

  depends_on = [module.aks, module.acr, module.network]
}
```

### 3. GitHub Actions Key Step

```yaml
- name: Deploy via Jump VM - Run Command
  uses: azure/CLI@v1
  with:
    inlineScript: |
      az vm run-command invoke \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${JUMP_VM_NAME}" \
        --command-id RunShellScript \
        --scripts "/opt/deploy/deploy.sh ${RESOURCE_GROUP} ${AKS_CLUSTER} ${IMAGE_TAG} ${ACR_SERVER}"
```

## 🔐 GitHub Secrets Configuration

Create these secrets in: **Settings → Secrets and Variables → Actions**

```
AZURE_CREDENTIALS          - Service Principal JSON
TF_VAR_SUBSCRIPTION_ID     - Your subscription ID
TF_VAR_TENANT_ID           - Your tenant ID
TF_VAR_ACR_NAME            - Container registry name
TF_VAR_AKS_CLUSTER_NAME    - AKS cluster name
TF_VAR_RESOURCE_GROUP_NAME - Resource group name
JUMP_VM_NAME                - Jump VM name (from Terraform output)
jumpvm_ssh_public_key      - Your SSH public key
```

## 📋 Step-by-Step Execution

### Step 1: Prepare Files

```bash
# Copy files to correct locations
cp terraform/modules/vm/variables-identity.tf      terraform/modules/vm/
cp terraform/modules/vm/main-identity.tf           terraform/modules/vm/
cp terraform/modules/vm/outputs-identity.tf        terraform/modules/vm/
cp terraform/scripts/jumpvm-cloud-init.yaml        terraform/scripts/
cp terraform/environments/dev/variables-jumpvm.tf  terraform/environments/dev/
cp terraform/environments/dev/outputs-jumpvm.tf    terraform/environments/dev/
cp .github/workflows/deploy-private-aks.yml        .github/workflows/
```

### Step 2: Update Existing Files

**terraform/modules/vm/main.tf**:
- Add `identity { type = "SystemAssigned" }` block to VM resource

**terraform/environments/dev/main.tf**:
- Add module call for jump_vm (see configuration template)

**terraform/environments/dev/terraform.tfvars**:
- Add Jump VM variables

### Step 3: Deploy Infrastructure

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### Step 4: Configure GitHub Secrets

```bash
# Get outputs
terraform output -json

# Manually add to GitHub Secrets:
# - JUMP_VM_NAME (from output: JUMP_VM_NAME)
# - Other secrets as listed above
```

### Step 5: Test Deployment

```bash
# Manually trigger workflow
# Go to Actions → Deploy workflow → Run workflow
```

## 🧪 Validation Commands

### Check VM Identity

```bash
az vm identity show \
  --resource-group <rg> \
  --name <vm-name> \
  --query systemAssignedIdentity
```

### Check Role Assignments

```bash
az role assignment list \
  --assignee <principal-id> \
  --output table
```

### Test Jump VM Connectivity

```bash
# SSH into Jump VM
ssh azureuser@<public-ip>

# Test managed identity
az login --identity

# Test AKS access
az aks get-credentials --resource-group <rg> --name <cluster>
kubectl cluster-info
```

### Monitor Deployment Script

```bash
# SSH into Jump VM
ssh azureuser@<public-ip>

# Run deployment manually
/opt/deploy/deploy.sh <rg> <cluster> <tag> <acr>

# View logs
tail -f /opt/deploy/logs/deploy-*.log
```

## 🚨 Common Pitfalls

| Issue | Solution |
|-------|----------|
| "authentication failed" | Verify identity block added to VM resource |
| "role assignment not found" | Run terraform apply to create assignments |
| "jumpvm not accessible" | Check network NSG rules allow your IP |
| "kubelogin not found" | Cloud-init not completed; wait ~5 minutes |
| "image pull errors" | Verify AcrPull role assignment exists |
| "deployment timeout" | Check Helm chart exists in correct location |

## 📞 Support Information

### Terraform State Issues

```bash
# If you need to refresh outputs
terraform refresh
terraform output JUMP_VM_NAME
```

### Azure CLI Debugging

```bash
# Enable debug logging
az --debug vm run-command invoke ...

# Check managed identity token
az account get-access-token --resource https://management.azure.com/
```

### Helm Debugging

```bash
# SSH into Jump VM
ssh azureuser@<public-ip>

# Check Helm releases
helm list -A

# View Helm deployment status
helm status <release> -n <namespace>

# Get deployment logs
kubectl logs -f deployment/ems-backend -n employee-management
```

---

**Last Updated**: 2024
**Version**: 1.0
**Status**: Production Ready
