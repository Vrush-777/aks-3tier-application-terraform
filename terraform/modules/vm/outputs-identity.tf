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
