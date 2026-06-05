# Managed Identity Module - outputs.tf

output "aks_identity_id" {
  description = "ID of the AKS managed identity"
  value       = azurerm_user_assigned_identity.aks_identity.id
}

output "aks_identity_principal_id" {
  description = "Principal ID of the AKS managed identity"
  value       = azurerm_user_assigned_identity.aks_identity.principal_id
}

output "aks_identity_client_id" {
  description = "Client ID of the AKS managed identity"
  value       = azurerm_user_assigned_identity.aks_identity.client_id
}

output "appgw_identity_id" {
  description = "ID of the Application Gateway managed identity"
  value       = azurerm_user_assigned_identity.appgw_identity.id
}

output "appgw_identity_principal_id" {
  description = "Principal ID of the Application Gateway managed identity"
  value       = azurerm_user_assigned_identity.appgw_identity.principal_id
}

output "appgw_identity_client_id" {
  description = "Client ID of the Application Gateway managed identity"
  value       = azurerm_user_assigned_identity.appgw_identity.client_id
}

output "kubelet_identity_id" {
  description = "ID of the Kubelet managed identity"
  value       = azurerm_user_assigned_identity.kubelet_identity.id
}

output "kubelet_identity_principal_id" {
  description = "Principal ID of the Kubelet managed identity"
  value       = azurerm_user_assigned_identity.kubelet_identity.principal_id
}

output "kubelet_identity_client_id" {
  description = "Client ID of the Kubelet managed identity"
  value       = azurerm_user_assigned_identity.kubelet_identity.client_id
}

output "aks_contributor_role_assignment_id" {
  description = "AKS Contributor Role Assignment ID"
  value       = azurerm_role_assignment.aks_contributor.id
}

output "appgw_contributor_role_assignment_id" {
  description = "Application Gateway Contributor Role Assignment ID"
  value       = azurerm_role_assignment.appgw_contributor.id
}

output "kubelet_acr_pull_role_assignment_id" {
  description = "Kubelet ACR Pull Role Assignment ID"
  value       = azurerm_role_assignment.kubelet_acr_pull.id
}