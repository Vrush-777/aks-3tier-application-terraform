# Network Module - outputs.tf

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.vnet.id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.vnet.name
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = azurerm_subnet.aks_subnet.id
}

output "aks_subnet_name" {
  description = "Name of the AKS subnet"
  value       = azurerm_subnet.aks_subnet.name
}

output "appgw_subnet_id" {
  description = "ID of the Application Gateway subnet"
  value       = azurerm_subnet.appgw_subnet.id
}

output "appgw_subnet_name" {
  description = "Name of the Application Gateway subnet"
  value       = azurerm_subnet.appgw_subnet.name
}

output "aks_nsg_id" {
  description = "ID of the AKS Network Security Group"
  value       = azurerm_network_security_group.aks_nsg.id
}

output "appgw_nsg_id" {
  description = "ID of the Application Gateway Network Security Group"
  value       = azurerm_network_security_group.appgw_nsg.id
}

output "postgres_subnet_id" {
  description = "ID of the PostgreSQL delegated subnet"
  value       = var.create_postgres_subnet ? azurerm_subnet.postgres_subnet[0].id : null
}
