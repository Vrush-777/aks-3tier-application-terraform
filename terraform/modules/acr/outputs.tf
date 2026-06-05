# Azure Container Registry Module - outputs.tf

output "acr_id" {
  description = "ID of the container registry"
  value       = azurerm_container_registry.acr.id
}

output "acr_name" {
  description = "Name of the container registry"
  value       = azurerm_container_registry.acr.name
}

output "acr_login_server" {
  description = "Login server for the container registry"
  value       = azurerm_container_registry.acr.login_server
}

output "acr_admin_username" {
  description = "Admin username for the container registry (if enabled)"
  value       = var.enable_admin_access ? azurerm_container_registry.acr.admin_username : null
  sensitive   = true
}

output "acr_admin_password" {
  description = "Admin password for the container registry (if enabled)"
  value       = var.enable_admin_access ? azurerm_container_registry.acr.admin_password : null
  sensitive   = true
}
