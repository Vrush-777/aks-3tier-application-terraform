#=============================================================================
# Identity and Deployment-related Outputs
# These outputs provide information needed by GitHub Actions and other deployment tools
#=============================================================================
output "vm_name" {
  value       = azurerm_linux_virtual_machine.jumpvm.name
  description = "Name of the Jump VM"
}

output "vm_principal_id" {
  value       = var.enable_managed_identity ? azurerm_linux_virtual_machine.jumpvm.identity[0].principal_id : null
  description = "Principal ID of the Jump VM's System Assigned Managed Identity"
}

output "vm_client_id" {
  value       = var.enable_managed_identity ? azurerm_linux_virtual_machine.jumpvm.identity[0].principal_id : null
  description = "Identifier exposed for the Jump VM's System Assigned Managed Identity"
}

output "resource_group_name" {
  value       = var.resource_group_name
  description = "Resource group name where the Jump VM is deployed"
}

output "resource_group_id" {
  value       = var.resource_group_id
  description = "Resource group ID where the Jump VM is deployed"
}

output "vm_private_ip" {
  value       = azurerm_network_interface.jumpvm.private_ip_address
  description = "Private IP address of the Jump VM"
}

output "vm_public_ip" {
  value       = azurerm_public_ip.jump_vm.ip_address
  description = "Public IP address of the Jump VM"
}

#=============================================================================
# Cloud-Init and Bootstrap Status Outputs
#
# These outputs are used by GitHub Actions to verify that cloud-init
# completed successfully before attempting deployments.
#
# VALIDATION WORKFLOW:
# 1. GitHub Actions retrieves these outputs
# 2. SSH into Jump VM using vm_public_ip
# 3. Check for bootstrap_marker_path existence
# 4. If missing, retrieve bootstrap_log_path for diagnostics
# 5. If bootstrap fails repeatedly, check diagnostics_path
#
# OUTPUTS EXPLAINED:
# - cloud_init_hash: Changes whenever cloud-init script changes
#   Trigger for: Terraform lifecycle rule (VM recreation)
# - bootstrap_marker_path: Created on bootstrap SUCCESS
#   Used by: CI/CD validation step to confirm bootstrap completion
# - bootstrap_log_path: Detailed bootstrap execution log
#   Used by: CI/CD diagnostics when bootstrap fails
# - diagnostics_path: Comprehensive system diagnostics on failure
#   Used by: Troubleshooting bootstrap failures
#=============================================================================

output "cloud_init_hash" {
  value       = local.jumpvm_cloud_init_hash
  description = "Hash of cloud-init content. Changes trigger VM replacement via Terraform lifecycle rule."
}

output "cloud_init_version" {
  value       = local.jumpvm_cloud_init_version
  description = "Version of cloud-init script being used"
}

output "bootstrap_marker_path" {
  value       = "/opt/deploy/.bootstrap-complete"
  description = "Path to bootstrap completion marker file on Jump VM. Created ONLY on successful bootstrap completion."
}

output "bootstrap_failed_marker_path" {
  value       = "/opt/deploy/.bootstrap-failed"
  description = "Path to bootstrap failure marker on Jump VM. Created if bootstrap encounters errors."
}

output "bootstrap_log_path" {
  value       = "/var/log/bootstrap-jumpvm.log"
  description = "Path to bootstrap execution log on Jump VM. Contains detailed stdout/stderr from all bootstrap operations."
}

output "cloud_init_log_path" {
  value       = "/var/log/cloud-init-output.log"
  description = "Path to cloud-init output log on Jump VM. Contains cloud-init framework messages."
}

output "cloud_init_main_log_path" {
  value       = "/var/lib/cloud/instance/boot-finished"
  description = "Path indicating cloud-init boot phase completion on Jump VM."
}

output "diagnostics_path" {
  value       = "/opt/deploy/.bootstrap-diagnostics"
  description = "Path to bootstrap diagnostics on Jump VM. Created on failure with system info, tool status, and logs."
}

output "deploy_script_path" {
  value       = "/opt/deploy/deploy.sh"
  description = "Path to deployment script on Jump VM. Created by bootstrap-jumpvm.sh during cloud-init."
}

output "deploy_directory" {
  value       = "/opt/deploy"
  description = "Root directory for deployment scripts and logs on Jump VM."
}

output "expected_tools" {
  value = {
    kubectl  = var.kubectl_version
    kubelogin = var.kubelogin_version
    helm     = "latest"
    azure_cli = "latest"
    jq       = "latest"
    git      = "latest"
    unzip    = "latest"
  }
  description = "Expected versions of tools installed by cloud-init bootstrap script."
}
