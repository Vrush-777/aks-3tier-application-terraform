# AKS Module - outputs.tf

output "aks_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "aks_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.fqdn
}

output "aks_private_fqdn" {
  description = "Private FQDN of the AKS cluster"
  value       = try(azurerm_kubernetes_cluster.aks.private_fqdn, "")
}

output "kube_config_raw" {
  description = "Raw kubeconfig"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "kube_config" {
  description = "Kubernetes config data"
  value       = azurerm_kubernetes_cluster.aks.kube_config
  sensitive   = true
}

output "client_certificate" {
  description = "Base64-encoded client certificate"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate
  sensitive   = true
}

output "client_key" {
  description = "Base64-encoded client key"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].client_key
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_username" {
  description = "Cluster username"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].username
  sensitive   = true
}

output "cluster_password" {
  description = "Cluster password"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].password
  sensitive   = true
}

output "kubernetes_version" {
  description = "Kubernetes version"
  value       = azurerm_kubernetes_cluster.aks.kubernetes_version
}

output "node_resource_group" {
  description = "Node resource group"
  value       = azurerm_kubernetes_cluster.aks.node_resource_group
}

output "admin_credentials" {
  description = "Admin credentials configuration"
  value       = try(azurerm_kubernetes_cluster.aks.kube_admin_config[0], null)
  sensitive   = true
}
