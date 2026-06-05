# Environment: Development
# Outputs from all modules

# ============================================================================
# Resource Group Outputs
# ============================================================================

output "resource_group_id" {
  description = "ID of the resource group"
  value       = module.resource_group.resource_group_id
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = module.resource_group.resource_group_name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = module.resource_group.location
}

# ============================================================================
# Network Outputs
# ============================================================================

output "vnet_id" {
  description = "ID of the virtual network"
  value       = module.network.vnet_id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = module.network.vnet_name
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = module.network.aks_subnet_id
}

output "appgw_subnet_id" {
  description = "ID of the Application Gateway subnet"
  value       = module.network.appgw_subnet_id
}

# ============================================================================
# Azure Container Registry Outputs
# ============================================================================

output "acr_id" {
  description = "ID of the container registry"
  value       = module.acr.acr_id
}

output "acr_name" {
  description = "Name of the container registry"
  value       = module.acr.acr_name
}

output "acr_login_server" {
  description = "Login server for the container registry"
  value       = module.acr.acr_login_server
}

# ============================================================================
# PostgreSQL Outputs
# ============================================================================

output "postgres_id" {
  description = "ID of the PostgreSQL server"
  value       = module.postgres.postgres_id
}

output "postgres_fqdn" {
  description = "FQDN of the PostgreSQL server"
  value       = module.postgres.postgres_fqdn
}

output "postgres_name" {
  description = "Name of the PostgreSQL server"
  value       = module.postgres.postgres_name
}

output "postgres_admin_username" {
  description = "PostgreSQL admin username"
  value       = module.postgres.postgres_admin_username
}

output "postgres_database_name" {
  description = "PostgreSQL database name"
  value       = module.postgres.database_name
}

output "postgres_connection_string" {
  description = "PostgreSQL connection string (without password)"
  value       = module.postgres.connection_string
}

# ============================================================================
# Application Gateway Outputs
# ============================================================================

output "appgw_id" {
  description = "ID of the Application Gateway"
  value       = module.application_gateway.appgw_id
}

output "appgw_name" {
  description = "Name of the Application Gateway"
  value       = module.application_gateway.appgw_name
}

output "appgw_public_ip" {
  description = "Public IP address of the Application Gateway"
  value       = module.application_gateway.appgw_pip_address
}

output "appgw_private_ip" {
  description = "Private IP address of the Application Gateway"
  value       = module.application_gateway.appgw_private_ip_address
}

# ============================================================================
# AKS Cluster Outputs
# ============================================================================

output "aks_id" {
  description = "ID of the AKS cluster"
  value       = module.aks.aks_id
}

output "aks_name" {
  description = "Name of the AKS cluster"
  value       = module.aks.aks_name
}

output "aks_fqdn" {
  description = "FQDN of the AKS cluster (public)"
  value       = module.aks.aks_fqdn
}

output "aks_private_fqdn" {
  description = "Private FQDN of the AKS cluster"
  value       = module.aks.aks_private_fqdn
}

output "aks_kubernetes_version" {
  description = "Kubernetes version of the AKS cluster"
  value       = module.aks.kubernetes_version
}

output "aks_node_resource_group" {
  description = "Node resource group of the AKS cluster"
  value       = module.aks.node_resource_group
}

# ============================================================================
# Kubeconfig Output (Sensitive)
# ============================================================================

output "kube_config_raw" {
  description = "Raw kubeconfig content (base64 encoded)"
  value       = module.aks.kube_config_raw
  sensitive   = true
}

output "kube_config" {
  description = "Kubernetes config data"
  value       = module.aks.kube_config
  sensitive   = true
}

# ============================================================================
# Managed Identity Outputs
# ============================================================================

output "aks_managed_identity_id" {
  description = "ID of the AKS managed identity"
  value       = module.managed_identity.aks_identity_id
}

output "appgw_managed_identity_id" {
  description = "ID of the Application Gateway managed identity"
  value       = module.managed_identity.appgw_identity_id
}

output "kubelet_managed_identity_id" {
  description = "ID of the Kubelet managed identity"
  value       = module.managed_identity.kubelet_identity_id
}

# ============================================================================
# Summary Output
# ============================================================================

output "deployment_summary" {
  description = "Summary of the deployment"
  value = {
    resource_group      = module.resource_group.resource_group_name
    location            = module.resource_group.location
    vnet_name           = module.network.vnet_name
    aks_cluster_name    = module.aks.aks_name
    aks_private_cluster = var.aks_private_cluster_enabled
    appgw_public_ip     = module.application_gateway.appgw_pip_address
    acr_login_server    = module.acr.acr_login_server
    postgres_fqdn       = module.postgres.postgres_fqdn
    kubernetes_version  = module.aks.kubernetes_version
    node_resource_group = module.aks.node_resource_group
  }
}
