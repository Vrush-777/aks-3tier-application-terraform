# ============================================================================
# Jump VM Module Configuration with Identity and Role Assignments
# ============================================================================
# ADD THIS SECTION TO: terraform/environments/dev/main.tf
#
# Location: After the ACR module and before any other resource that might need
# to reference the Jump VM

# Jump VM Module
module "jump_vm" {
  source = "../../modules/vm"

  # Basic configuration
  resource_group_name = module.resource_group.resource_group_name
  location            = module.resource_group.location
  prefix              = var.prefix
  admin_username      = var.jumpvm_admin_username
  ssh_public_key      = var.jumpvm_ssh_public_key
  subnet_id           = module.network.jumpvm_subnet_id  # or use your existing subnet
  nsg_id              = module.network.jumpvm_nsg_id     # or use your existing NSG
  vm_size             = var.jumpvm_vm_size

  # Identity and role assignment configuration
  enable_managed_identity = true
  
  # Pass resource IDs for role assignments
  aks_cluster_id  = module.aks.aks_id
  acr_id          = module.acr.acr_id
  resource_group_id = module.resource_group.resource_group_id

  # Tags
  tags = merge(
    var.common_tags,
    {
      Name = "${var.prefix}-jumpvm"
      Role = "PrivateAKSDeploymentVM"
    }
  )

  # Ensure dependencies are properly ordered
  depends_on = [
    module.aks,
    module.acr,
    module.network
  ]
}

# ============================================================================
# Role Assignments for Jump VM Managed Identity
# ============================================================================
# These are created by the vm module's main-identity.tf file, but this is
# the conceptual location where they are defined in the environment config

# NOTE: The actual role assignments are defined in:
# terraform/modules/vm/main-identity.tf
#
# They automatically use:
# - azurerm_role_assignment.jumpvm_aks_user (AKS Cluster User)
# - azurerm_role_assignment.jumpvm_rg_reader (Reader on RG)
# - azurerm_role_assignment.jumpvm_acr_pull (AcrPull on ACR)

# ============================================================================
# Output Jump VM Details for GitHub Actions
# ============================================================================
# These outputs should be added to environments/dev/outputs.tf
# (see separate outputs file for full details)
