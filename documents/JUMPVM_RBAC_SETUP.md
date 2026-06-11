# Jump VM RBAC Role Assignments for Private AKS Deployment

## Overview

This document describes how to configure role assignments for a Jump VM to enable automated deployments into a private AKS cluster using its system-assigned managed identity.

## Architecture

The Jump VM uses a **system-assigned managed identity** to authenticate to three Azure resources:

1. **AKS Cluster** — `Azure Kubernetes Service Cluster User Role`  
   Allows the Jump VM to authenticate to the AKS cluster via `kubectl`.

2. **Resource Group** — `Reader` role  
   Allows the Jump VM to read resource metadata (e.g., AKS cluster details, network information).

3. **Azure Container Registry (ACR)** — `AcrPull` role  
   Allows the Jump VM to pull container images from ACR during deployments.

## Terraform Implementation

### File Structure

```
terraform/
├── environments/dev/
│   ├── main.tf                    # Module calls (includes rbac.tf via local)
│   ├── rbac.tf                    # Role assignments (THIS FILE)
│   ├── variables.tf               # Root variables
│   └── terraform.tfvars           # Variable values (example shown below)
├── modules/
│   └── vm/
│       ├── main.tf                # VM resource with identity block
│       └── outputs.tf             # VM outputs (includes vm_principal_id)
└── JUMPVM_RBAC_SETUP.md           # This file
```

### Role Assignment Resources

#### File: `terraform/environments/dev/rbac.tf`

This file contains:

**Data Sources** (lookup built-in Azure roles):
```hcl
data "azurerm_role_definition" "aks_cluster_user" {
  name  = "Azure Kubernetes Service Cluster User Role"
  scope = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
}

data "azurerm_role_definition" "reader" {
  name  = "Reader"
  scope = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
}

data "azurerm_role_definition" "acr_pull" {
  name  = "AcrPull"
  scope = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
}
```

**Input Variables**:
```hcl
variable "jump_vm_principal_id" {
  description = "Principal ID of the Jump VM's system-assigned managed identity."
  type        = string
}

variable "aks_id" {
  description = "Resource ID of the AKS cluster."
  type        = string
}

variable "acr_id" {
  description = "Resource ID of the Azure Container Registry."
  type        = string
}

variable "resource_group_id" {
  description = "Resource ID of the resource group."
  type        = string
}
```

**Role Assignments**:
```hcl
resource "azurerm_role_assignment" "jumpvm_aks_user" {
  count = local.jumpvm_identity_present && var.aks_id != "" ? 1 : 0
  
  scope              = var.aks_id
  role_definition_id = data.azurerm_role_definition.aks_cluster_user.id
  principal_id       = var.jump_vm_principal_id
}

resource "azurerm_role_assignment" "jumpvm_rg_reader" {
  count = local.jumpvm_identity_present && var.resource_group_id != "" ? 1 : 0
  
  scope              = var.resource_group_id
  role_definition_id = data.azurerm_role_definition.reader.id
  principal_id       = var.jump_vm_principal_id
}

resource "azurerm_role_assignment" "jumpvm_acr_pull" {
  count = local.jumpvm_identity_present && var.acr_id != "" ? 1 : 0
  
  scope              = var.acr_id
  role_definition_id = data.azurerm_role_definition.acr_pull.id
  principal_id       = var.jump_vm_principal_id
}
```

### Wire-Up in Root Configuration

In `terraform/environments/dev/main.tf`, add the role assignment variables after the module calls:

```hcl
# After all module definitions, pass outputs to rbac.tf variables

variable "jump_vm_principal_id" {
  type = string
}

variable "aks_id" {
  type = string
}

variable "acr_id" {
  type = string
}

variable "resource_group_id" {
  type = string
}
```

### Terraform Variables File Example

File: `terraform/environments/dev/terraform.tfvars`

```hcl
# ============================================================================
# Subscription & Authentication
# ============================================================================
subscription_id = "12345678-1234-1234-1234-123456789abc"
tenant_id       = "87654321-4321-4321-4321-abcdef123456"

# ... existing variables ...

# ============================================================================
# Jump VM RBAC Configuration
# ============================================================================
# These values come from module outputs:
# - module.jump_vm.vm_principal_id
# - module.aks.aks_id
# - module.acr.acr_id
# - module.resource_group.resource_group_id

# For initial apply, populate after first terraform apply
# Then retrieve from terraform output and add to tfvars:

# jump_vm_principal_id = "12345678-abcd-1234-abcd-123456789abc"  # Uncomment after initial apply
# aks_id               = "/subscriptions/12345678.../providers/Microsoft.ContainerService/managedClusters/aks-dev"
# acr_id               = "/subscriptions/12345678.../providers/Microsoft.ContainerRegistry/registries/acrdev"
# resource_group_id    = "/subscriptions/12345678.../resourceGroups/rg-dev"
```

### Alternative: Use Terraform Locals

Instead of passing variables through `terraform.tfvars`, you can use **locals** to wire up module outputs directly. Add this to `terraform/environments/dev/main.tf`:

```hcl
locals {
  rbac_config = {
    jump_vm_principal_id = module.jump_vm.vm_principal_id
    aks_id               = module.aks.aks_id
    acr_id               = module.acr.acr_id
    resource_group_id    = module.resource_group.resource_group_id
  }
}
```

Then reference in `rbac.tf`:

```hcl
# In rbac.tf instead of variables, use locals:
# jump_vm_principal_id = local.rbac_config.jump_vm_principal_id
# aks_id               = local.rbac_config.aks_id
# acr_id               = local.rbac_config.acr_id
# resource_group_id    = local.rbac_config.resource_group_id
```

## Terraform Plan Output

When you run `terraform plan`, you should see three new resources (assuming `jumpvm_identity_present` is true):

```
Plan: 3 to add, 0 to change, 0 to destroy.

+ azurerm_role_assignment.jumpvm_aks_user
+ azurerm_role_assignment.jumpvm_rg_reader
+ azurerm_role_assignment.jumpvm_acr_pull
```

## Deployment Steps

1. **Update module outputs** to include `vm_principal_id` (already done in `terraform/modules/vm/outputs.tf`).

2. **Create or update `rbac.tf`** in `terraform/environments/dev/` with role assignment resources.

3. **Update `terraform.tfvars`** or environment with Jump VM identity outputs:
   ```bash
   terraform apply -target module.jump_vm
   terraform output -json | jq '.jumpvm_principal_id.value' > /tmp/principal_id.txt
   ```

4. **Uncomment and populate rbac variables** in `terraform.tfvars`.

5. **Apply RBAC changes**:
   ```bash
   terraform plan
   terraform apply
   ```

6. **Verify role assignments** (Azure CLI):
   ```bash
   az role assignment list --assignee <principal_id> --output table
   ```

## Verification

After deployment, verify role assignments using Azure CLI:

```bash
PRINCIPAL_ID=$(terraform output -raw jumpvm_principal_id)

# List all role assignments for the Jump VM identity
az role assignment list --assignee $PRINCIPAL_ID --output table

# Expected output:
# Scope: /subscriptions/.../resourceGroups/<rg>/providers/Microsoft.ContainerService/managedClusters/<aks>
# Role: Azure Kubernetes Service Cluster User Role
#
# Scope: /subscriptions/.../resourceGroups/<rg>
# Role: Reader
#
# Scope: /subscriptions/.../resourceGroups/<rg>/providers/Microsoft.ContainerRegistry/registries/<acr>
# Role: AcrPull
```

## GitHub Actions Integration

For automated deployments from GitHub Actions, pass these role assignments to the runner:

```yaml
- name: Deploy to AKS via Jump VM
  run: |
    export VM_PRINCIPAL_ID=$(terraform output -raw jumpvm_principal_id)
    export AKS_CLUSTER_ID=$(terraform output -raw aks_id)
    
    # Verify role assignment exists
    az role assignment list --assignee $VM_PRINCIPAL_ID \
      --scope $AKS_CLUSTER_ID --output table
```

## Troubleshooting

### Issue: `PrincipalNotFound` when creating role assignments

**Cause**: The managed identity has not been created yet or the principal ID is empty.

**Solution**:
1. Ensure `azurerm_linux_virtual_machine` has the `identity { type = "SystemAssigned" }` block.
2. Apply the VM module first: `terraform apply -target module.jump_vm`
3. Retrieve the principal ID from the output.

### Issue: Role assignment fails with `Authorization failed` error

**Cause**: Your Terraform service principal lacks permission to create role assignments.

**Solution**:
1. Ensure your Terraform service principal has **`User Access Administrator`** or **`Owner`** role on the subscription.
2. Add RBAC to your service principal:
   ```bash
   az role assignment create --role "User Access Administrator" \
     --assignee <service-principal-id> \
     --scope /subscriptions/<subscription-id>
   ```

### Issue: Role names do not resolve

**Cause**: Role lookup may fail if the Azure CLI context differs from the Terraform context.

**Solution**:
Use `role_definition_id` instead of `role_definition_name`:
```hcl
role_definition_id = data.azurerm_role_definition.aks_cluster_user.id
```
(Already implemented in the provided code.)

## Related Files

- `terraform/modules/vm/main.tf` — VM resource with system-assigned identity
- `terraform/modules/vm/outputs.tf` — Exports `vm_principal_id`
- `terraform/environments/dev/rbac.tf` — Role assignment definitions
- `terraform/environments/dev/main.tf` — Module orchestration
