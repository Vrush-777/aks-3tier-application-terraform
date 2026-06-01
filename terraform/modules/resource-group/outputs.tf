# Azure Resource Group Module - outputs.tf

output "resource_group_id" {
  description = "ID of the created resource group"
  value       = azurerm_resource_group.rg.id
}

output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.rg.name
}

output "location" {
  description = "Azure region of the resource group"
  value       = azurerm_resource_group.rg.location
}
