# Identity and Deployment-related Outputs
# These outputs provide information needed by GitHub Actions and other deployment tools

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
#=============================================================================
output "cloud_init_hash" {
  value       = local.jumpvm_cloud_init_hash
  description = "Hash of cloud-init content. Changes trigger VM replacement."
}

output "cloud_init_version" {
  value       = "enhanced-v1.0"
  description = "Version of cloud-init script being used"
}

output "bootstrap_marker_path" {
  value       = "/opt/deploy/.bootstrap-complete"
  description = "Path to bootstrap completion marker file on Jump VM"
}

output "bootstrap_log_path" {
  value       = "/var/log/bootstrap-jumpvm.log"
  description = "Path to bootstrap execution log on Jump VM"
}

output "deploy_script_path" {
  value       = "/opt/deploy/deploy.sh"
  description = "Path to deployment script on Jump VM"
}

output "expected_tools" {
  value = {
    kubectl  = var.kubectl_version
    kubelogin = var.kubelogin_version
    helm     = "latest"
    azure_cli = "latest"
  }
  description = "Expected versions of tools installed by cloud-init"
}
