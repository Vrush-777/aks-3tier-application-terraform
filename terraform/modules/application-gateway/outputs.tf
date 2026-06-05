# Application Gateway Module - outputs.tf

output "appgw_id" {
  description = "ID of the Application Gateway"
  value       = azurerm_application_gateway.appgw.id
}

output "appgw_name" {
  description = "Name of the Application Gateway"
  value       = azurerm_application_gateway.appgw.name
}

output "appgw_pip_id" {
  description = "ID of the public IP"
  value       = azurerm_public_ip.appgw_pip.id
}

output "appgw_pip_address" {
  description = "Public IP address of the Application Gateway"
  value       = azurerm_public_ip.appgw_pip.ip_address
}

# output "appgw_private_ip_address" {
#   description = "Private IP address of the Application Gateway"

#   value = one([
#     for cfg in azurerm_application_gateway.appgw.frontend_ip_configuration :
#     cfg.private_ip_address
#     if try(cfg.private_ip_address, null) != null
#   ])
# }

output "appgw_private_ip_address" {
  value = try(
    [
      for cfg in azurerm_application_gateway.appgw.frontend_ip_configuration :
      cfg.private_ip_address
      if try(cfg.private_ip_address, null) != null
    ][0],
    null
  )
}

output "appgw_backend_pool_id" {
  description = "Backend Pool ID"
  value = one([
    for pool in azurerm_application_gateway.appgw.backend_address_pool :
    pool.id
  ])
}
