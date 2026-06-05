# Environment: Development
# Variables file for dev environment

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
  sensitive   = true
}

# ============================================================================
# Resource Group Variables
# ============================================================================

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "East US"
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "ems"
    ManagedBy   = "Terraform"
  }
}

# ============================================================================
# Network Variables
# ============================================================================

variable "vnet_name" {
  description = "Virtual network name"
  type        = string
}

variable "address_space" {
  description = "Address space for virtual network"
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "aks_subnet_name" {
  description = "AKS subnet name"
  type        = string
  default     = "aks-subnet"
}

variable "aks_subnet_address_prefixes" {
  description = "Address prefixes for AKS subnet"
  type        = list(string)
  default     = ["10.1.1.0/24"]
}

variable "appgw_subnet_name" {
  description = "Application Gateway subnet name"
  type        = string
  default     = "appgw-subnet"
}

variable "appgw_subnet_address_prefixes" {
  description = "Address prefixes for Application Gateway subnet"
  type        = list(string)
  default     = ["10.1.2.0/24"]
}

variable "postgres_subnet_name" {
  description = "Name of the PostgreSQL subnet"
  type        = string
  default     = "postgres-subnet"
}

variable "postgres_subnet_address_prefixes" {
  description = "Address prefixes for PostgreSQL subnet"
  type        = list(string)
  default     = ["10.1.3.0/24"]
}

variable "create_postgres_subnet" {
  description = "Create a dedicated PostgreSQL subnet"
  type        = bool
  default     = true
}

variable "aks_nsg_name" {
  description = "Network Security Group for AKS"
  type        = string
  default     = "aks-nsg"
}

variable "appgw_nsg_name" {
  description = "Network Security Group for Application Gateway"
  type        = string
  default     = "appgw-nsg"
}

variable "create_route_table" {
  description = "Create route table for AKS"
  type        = bool
  default     = false
}

variable "aks_route_table_name" {
  description = "Route table name for AKS"
  type        = string
  default     = "aks-route-table"
}

# ============================================================================
# Azure Container Registry Variables
# ============================================================================

variable "acr_name" {
  description = "Azure Container Registry name (globally unique, 5-50 alphanumeric)"
  type        = string
}

variable "acr_sku" {
  description = "ACR SKU (Basic, Standard, Premium)"
  type        = string
  default     = "Premium"
}

variable "acr_enable_admin_access" {
  description = "Enable admin user for ACR"
  type        = bool
  default     = false
}

variable "acr_enable_public_network" {
  description = "Enable public network access to ACR"
  type        = bool
  default     = true
}

variable "acr_enable_private_endpoint" {
  description = "Create private endpoint for ACR"
  type        = bool
  default     = false
}

# ============================================================================
# PostgreSQL Variables
# ============================================================================

variable "postgres_server_name" {
  description = "PostgreSQL server name (globally unique, 3-63 alphanumeric-hyphen)"
  type        = string
}

variable "postgres_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "16"
}

variable "postgres_sku_name" {
  description = "PostgreSQL SKU (e.g., B_Standard_B2s, D_Standard_D2s_v3)"
  type        = string
  default     = "B_Standard_B2s"
}

variable "postgres_admin_username" {
  description = "PostgreSQL admin username"
  type        = string
  default     = "adminuser"
}

variable "postgres_admin_password" {
  description = "PostgreSQL admin password (must meet complexity requirements)"
  type        = string
  sensitive   = true
}

variable "postgres_storage_mb" {
  description = "PostgreSQL storage in MB (32768-1048576)"
  type        = number
  default     = 65536
}

variable "postgres_backup_retention_days" {
  description = "Backup retention days (7-35)"
  type        = number
  default     = 7
}

variable "postgres_ha_mode" {
  description = "High Availability mode (Disabled, ZoneRedundant)"
  type        = string
  default     = "Disabled"
}

variable "postgres_standby_az" {
  description = "Standby availability zone for PostgreSQL HA"
  type        = string
  default     = "2"
}

variable "postgres_ssl_enforce" {
  description = "Enforce SSL for PostgreSQL"
  type        = bool
  default     = true
}

variable "postgres_geo_redundant_backup" {
  description = "Enable geo-redundant backups for PostgreSQL"
  type        = bool
  default     = true
}

variable "postgres_database_name" {
  description = "Initial database name"
  type        = string
  default     = "employee_db"
}

variable "postgres_max_connections" {
  description = "Maximum PostgreSQL connections"
  type        = number
  default     = 100
}

# ============================================================================
# Managed Identity Variables
# ============================================================================

variable "aks_identity_name" {
  description = "AKS managed identity name"
  type        = string
  default     = "aks-identity"
}

variable "appgw_identity_name" {
  description = "Application Gateway managed identity name"
  type        = string
  default     = "appgw-identity"
}

variable "kubelet_identity_name" {
  description = "Kubelet managed identity name"
  type        = string
  default     = "kubelet-identity"
}

# ============================================================================
# Application Gateway Variables
# ============================================================================

variable "appgw_name" {
  description = "Application Gateway name"
  type        = string
}

variable "appgw_pip_name" {
  description = "Application Gateway public IP name"
  type        = string
  default     = "appgw-pip"
}

variable "appgw_sku_name" {
  description = "Application Gateway SKU (Standard_v2, WAF_v2)"
  type        = string
  default     = "Standard_v2"
}

variable "appgw_tier" {
  description = "Application Gateway tier"
  type        = string
  default     = "Standard_v2"
}

variable "appgw_capacity" {
  description = "Application Gateway capacity (1-125)"
  type        = number
  default     = 2
}

variable "appgw_private_ip_address" {
  description = "Application Gateway private IP"
  type        = string
  default     = "10.1.2.10"
}

variable "appgw_tls_enabled" {
  description = "Enable TLS/HTTPS for Application Gateway"
  type        = bool
  default     = false
}

variable "appgw_ssl_certificate_path" {
  description = "Path to SSL certificate (PFX)"
  type        = string
  default     = ""
}

variable "appgw_ssl_certificate_password" {
  description = "SSL certificate password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "appgw_enable_waf" {
  description = "Enable Web Application Firewall"
  type        = bool
  default     = false
}

variable "appgw_waf_mode" {
  description = "WAF mode (Detection, Prevention)"
  type        = string
  default     = "Prevention"
}

variable "appgw_waf_rule_set_type" {
  description = "WAF rule set type"
  type        = string
  default     = "OWASP"
}

variable "appgw_waf_rule_set_version" {
  description = "WAF rule set version"
  type        = string
  default     = "3.2"
}

# ============================================================================
# AKS Cluster Variables
# ============================================================================

variable "aks_cluster_name" {
  description = "AKS cluster name"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.34.7"
}

variable "aks_default_node_pool_name" {
  description = "Default AKS node pool name"
  type        = string
  default     = "systempool"
}

variable "aks_default_node_pool_count" {
  description = "Default AKS node pool count"
  type        = number
  default     = 3
}

variable "aks_default_node_pool_vm_size" {
  description = "Default AKS node pool VM size"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "aks_os_disk_size_gb" {
  description = "AKS OS disk size in GB"
  type        = number
  default     = 30
}

variable "aks_enable_auto_scaling" {
  description = "Enable AKS auto-scaling"
  type        = bool
  default     = true
}

variable "aks_min_count" {
  description = "Minimum AKS node count"
  type        = number
  default     = 3
}

variable "aks_max_count" {
  description = "Maximum AKS node count"
  type        = number
  default     = 10
}

variable "aks_availability_zones" {
  description = "AKS availability zones"
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "aks_node_labels" {
  description = "AKS node labels"
  type        = map(string)
  default     = {}
}

variable "aks_node_taints" {
  description = "AKS node taints"
  type        = list(string)
  default     = []
}

variable "aks_network_policy" {
  description = "AKS network policy (azure, calico)"
  type        = string
  default     = "azure"
}

variable "aks_dns_service_ip" {
  description = "AKS DNS service IP"
  type        = string
  default     = "10.2.0.10"
}

# variable "aks_docker_bridge_cidr" {
#   description = "AKS docker bridge CIDR"
#   type        = string
#   default     = "172.17.0.1/16"
# }

variable "aks_service_cidr" {
  description = "AKS service CIDR"
  type        = string
  default     = "10.2.0.0/16"
}

variable "aks_outbound_type" {
  description = "AKS outbound type (loadBalancer, userDefinedRouting)"
  type        = string
  default     = "loadBalancer"
}

variable "aks_private_cluster_enabled" {
  description = "Enable private AKS cluster"
  type        = bool
  default     = true
}

variable "aks_private_dns_zone_id" {
  description = "Private DNS zone ID for AKS"
  type        = string
  default     = "System"
}

variable "aks_admin_group_object_ids" {
  description = "Azure AD group object IDs for AKS admin access"
  type        = list(string)
  default     = []
}

variable "aks_enable_azure_policy" {
  description = "Enable Azure Policy for AKS"
  type        = bool
  default     = true
}

variable "aks_automatic_channel_upgrade" {
  description = "AKS auto-upgrade channel (patch, rapid, stable, node-image)"
  type        = string
  default     = "patch"
}

variable "aks_node_os_channel_upgrade" {
  description = "AKS node OS upgrade channel"
  type        = string
  default     = "SecurityPatch"
}

variable "aks_enable_maintenance_window" {
  description = "Enable AKS maintenance window"
  type        = bool
  default     = false
}

variable "aks_maintenance_window_day" {
  description = "AKS maintenance window day"
  type        = string
  default     = "Sunday"
}

variable "aks_maintenance_window_duration" {
  description = "AKS maintenance window duration (hours)"
  type        = number
  default     = 4
}

variable "aks_maintenance_window_start_time" {
  description = "AKS maintenance window start time (HH:MM)"
  type        = string
  default     = "02:00"
}

variable "aks_additional_node_pools" {
  description = "Additional AKS node pools"
  type = map(object({
    node_count          = number
    vm_size             = string
    availability_zones  = list(string)
    os_disk_size_gb     = number
    enable_auto_scaling = bool
    min_count           = number
    max_count           = number
    node_labels         = map(string)
    node_taints         = list(string)
    priority            = string
    spot_max_price      = optional(number)
  }))
  default = {}
}

# ============================================================================
# Diagnostic & Monitoring Variables
# ============================================================================

variable "enable_diagnostics" {
  description = "Enable diagnostic settings for resources"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for diagnostics"
  type        = string
  default     = ""
}
