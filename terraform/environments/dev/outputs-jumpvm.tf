# ============================================================================
# Jump VM Related Outputs
# ============================================================================
# ADD THESE OUTPUTS TO: terraform/environments/dev/outputs.tf
#
# These outputs are essential for GitHub Actions workflow integration

# ============================================================================
# Jump VM Basic Information
# ============================================================================

output "jump_vm_name" {
  description = "Name of the Jump VM used for private AKS deployment"
  value       = module.jump_vm.vm_name
}

output "jump_vm_public_ip" {
  description = "Public IP address of the Jump VM (for SSH access)"
  value       = module.jump_vm.vm_public_ip
}

output "jump_vm_private_ip" {
  description = "Private IP address of the Jump VM"
  value       = module.jump_vm.vm_private_ip
}

output "jump_vm_resource_group" {
  description = "Resource group where Jump VM is deployed"
  value       = module.jump_vm.resource_group_name
}

# ============================================================================
# Jump VM Managed Identity Outputs
# ============================================================================

output "jump_vm_principal_id" {
  description = "Principal ID of the Jump VM's System Assigned Managed Identity (for role assignments)"
  value       = module.jump_vm.vm_principal_id
  sensitive   = false
}

output "jump_vm_client_id" {
  description = "Client ID of the Jump VM's System Assigned Managed Identity"
  value       = module.jump_vm.vm_client_id
  sensitive   = false
}

# ============================================================================
# Deployment Information for GitHub Actions
# ============================================================================

output "deployment_config" {
  description = "Configuration values needed for deployment via GitHub Actions"
  value = {
    jump_vm_name       = module.jump_vm.vm_name
    resource_group     = module.jump_vm.resource_group_name
    aks_cluster_name   = module.aks.aks_name
    aks_resource_group = module.resource_group.resource_group_name
    acr_login_server   = module.acr.acr_login_server
    deployment_script  = "/opt/deploy/deploy.sh"
    jumpvm_public_ip   = module.jump_vm.vm_public_ip
    helm_namespace     = "employee-management"
    helm_release       = "ems"
  }
  sensitive = false
}

# ============================================================================
# Infrastructure Summary
# ============================================================================

output "infrastructure_summary" {
  description = "Complete infrastructure summary for reference"
  value = {
    resource_group_name      = module.resource_group.resource_group_name
    region                   = module.resource_group.location
    aks_cluster_name         = module.aks.aks_name
    aks_is_private_cluster   = var.aks_private_cluster_enabled
    acr_name                 = module.acr.acr_name
    postgres_server_name     = module.postgres.postgres_name
    jump_vm_name             = module.jump_vm.vm_name
    jump_vm_managed_identity = module.jump_vm.vm_principal_id
    deployment_method        = "Private AKS via Jump VM with Managed Identity"
  }
}
