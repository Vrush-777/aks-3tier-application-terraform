# Environment: Development
# Location: /terraform/environments/dev/
# Main configuration file that calls all modules

terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }

  # Uncomment and configure for remote state management
  # backend "azurerm" {
  #   resource_group_name  = "terraform-rg"
  #   storage_account_name = "terraformstate"
  #   container_name       = "tfstate"
  #   key                  = "aks-prod.tfstate"
  # }
}

provider "azurerm" {
  features {
    virtual_machine {
      graceful_shutdown = true
    }
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

provider "kubernetes" {
  host                   = module.aks.aks_fqdn != "" ? "https://${module.aks.aks_fqdn}:443" : "https://${module.aks.aks_private_fqdn}:443"
  client_certificate     = base64decode(module.aks.client_certificate)
  client_key             = base64decode(module.aks.client_key)
  cluster_ca_certificate = base64decode(module.aks.cluster_ca_certificate)
}

# Resource Group
module "resource_group" {
  source = "../../modules/resource-group"

  resource_group_name = var.resource_group_name
  location            = var.location
  common_tags         = var.common_tags
}

# Network
module "network" {
  source = "../../modules/network"

  resource_group_name             = module.resource_group.resource_group_name
  location                        = module.resource_group.location
  vnet_name                       = var.vnet_name
  address_space                   = var.address_space
  aks_subnet_name                 = var.aks_subnet_name
  aks_subnet_address_prefixes     = var.aks_subnet_address_prefixes
  appgw_subnet_name               = var.appgw_subnet_name
  appgw_subnet_address_prefixes   = var.appgw_subnet_address_prefixes
  aks_nsg_name                    = var.aks_nsg_name
  appgw_nsg_name                  = var.appgw_nsg_name
  create_route_table              = var.create_route_table
  aks_route_table_name            = var.aks_route_table_name
  common_tags                     = var.common_tags
}

# Azure Container Registry
module "acr" {
  source = "../../modules/acr"

  acr_name                   = var.acr_name
  location                   = module.resource_group.location
  resource_group_name        = module.resource_group.resource_group_name
  acr_sku                    = var.acr_sku
  enable_admin_access        = var.acr_enable_admin_access
  enable_public_network      = var.acr_enable_public_network
  enable_private_endpoint    = var.acr_enable_private_endpoint
  private_endpoint_subnet_id = var.acr_enable_private_endpoint ? module.network.aks_subnet_id : ""
  enable_diagnostics         = var.enable_diagnostics
  log_analytics_workspace_id = var.enable_diagnostics ? var.log_analytics_workspace_id : ""
  common_tags                = var.common_tags
}

# PostgreSQL Database
module "postgres" {
  source = "../../modules/postgres"

  postgres_server_name        = var.postgres_server_name
  location                    = module.resource_group.location
  resource_group_name         = module.resource_group.resource_group_name
  sku_name                    = var.postgres_sku_name
  postgres_version            = var.postgres_version
  admin_username              = var.postgres_admin_username
  admin_password              = var.postgres_admin_password
  storage_mb                  = var.postgres_storage_mb
  backup_retention_days       = var.postgres_backup_retention_days
  high_availability_mode      = var.postgres_ha_mode
  standby_availability_zone   = var.postgres_standby_az
  delegated_subnet_id         = module.network.aks_subnet_id
  vnet_id                     = module.network.vnet_id
  ssl_enforce                 = var.postgres_ssl_enforce
  geo_redundant_backup        = var.postgres_geo_redundant_backup
  database_name               = var.postgres_database_name
  max_connections             = var.postgres_max_connections
  enable_diagnostics          = var.enable_diagnostics
  log_analytics_workspace_id  = var.enable_diagnostics ? var.log_analytics_workspace_id : ""
  common_tags                 = var.common_tags
}

# Managed Identities (must be created before AKS)
module "managed_identity" {
  source = "../../modules/managed-identity"

  resource_group_name  = module.resource_group.resource_group_name
  resource_group_id    = module.resource_group.resource_group_id
  location             = module.resource_group.location
  aks_identity_name    = var.aks_identity_name
  appgw_identity_name  = var.appgw_identity_name
  kubelet_identity_name = var.kubelet_identity_name
  acr_id               = module.acr.acr_id
  common_tags          = var.common_tags
}

# Application Gateway
module "application_gateway" {
  source = "../../modules/application-gateway"

  appgw_name                = var.appgw_name
  location                  = module.resource_group.location
  resource_group_name       = module.resource_group.resource_group_name
  appgw_subnet_id           = module.network.appgw_subnet_id
  appgw_pip_name            = var.appgw_pip_name
  appgw_sku_name            = var.appgw_sku_name
  appgw_tier                = var.appgw_tier
  appgw_capacity            = var.appgw_capacity
  appgw_private_ip_address  = var.appgw_private_ip_address
  tls_enabled               = var.appgw_tls_enabled
  ssl_certificate_path      = var.appgw_ssl_certificate_path
  ssl_certificate_password  = var.appgw_ssl_certificate_password
  enable_waf                = var.appgw_enable_waf
  waf_mode                  = var.appgw_waf_mode
  waf_rule_set_type         = var.appgw_waf_rule_set_type
  waf_rule_set_version      = var.appgw_waf_rule_set_version
  enable_diagnostics        = var.enable_diagnostics
  log_analytics_workspace_id = var.enable_diagnostics ? var.log_analytics_workspace_id : ""
  common_tags               = var.common_tags
}

# AKS Cluster
module "aks" {
  source = "../../modules/aks"

  aks_cluster_name               = var.aks_cluster_name
  location                       = module.resource_group.location
  resource_group_name            = module.resource_group.resource_group_name
  kubernetes_version             = var.kubernetes_version
  default_node_pool_name         = var.aks_default_node_pool_name
  default_node_pool_count        = var.aks_default_node_pool_count
  default_node_pool_vm_size      = var.aks_default_node_pool_vm_size
  aks_subnet_id                  = module.network.aks_subnet_id
  os_disk_size_gb                = var.aks_os_disk_size_gb
  enable_auto_scaling            = var.aks_enable_auto_scaling
  min_count                      = var.aks_min_count
  max_count                      = var.aks_max_count
  availability_zones             = var.aks_availability_zones
  node_labels                    = var.aks_node_labels
  node_taints                    = var.aks_node_taints
  network_plugin                 = "azure"  # Azure CNI
  network_policy                 = var.aks_network_policy
  dns_service_ip                 = var.aks_dns_service_ip
  docker_bridge_cidr             = var.aks_docker_bridge_cidr
  service_cidr                   = var.aks_service_cidr
  outbound_type                  = var.aks_outbound_type
  private_cluster_enabled        = var.aks_private_cluster_enabled
  private_dns_zone_id            = var.aks_private_dns_zone_id
  aks_managed_identity_id        = module.managed_identity.aks_identity_id
  kubelet_client_id              = module.managed_identity.kubelet_identity_client_id
  kubelet_object_id              = module.managed_identity.kubelet_identity_principal_id
  kubelet_identity_id            = module.managed_identity.kubelet_identity_id
  admin_group_object_ids         = var.aks_admin_group_object_ids
  appgw_id                       = module.application_gateway.appgw_id
  appgw_name                     = module.application_gateway.appgw_name
  appgw_subnet_cidr              = var.appgw_subnet_address_prefixes[0]
  appgw_subnet_id                = module.network.appgw_subnet_id
  enable_azure_policy            = var.aks_enable_azure_policy
  automatic_channel_upgrade      = var.aks_automatic_channel_upgrade
  node_os_channel_upgrade        = var.aks_node_os_channel_upgrade
  enable_maintenance_window      = var.aks_enable_maintenance_window
  maintenance_window_day         = var.aks_maintenance_window_day
  maintenance_window_duration    = var.aks_maintenance_window_duration
  maintenance_window_start_time  = var.aks_maintenance_window_start_time
  additional_node_pools          = var.aks_additional_node_pools
  kubelet_role_assignment_id     = module.managed_identity.kubelet_acr_pull_role_assignment_id
  aks_role_assignment_id         = module.managed_identity.aks_contributor_role_assignment_id
  common_tags                    = var.common_tags
}
