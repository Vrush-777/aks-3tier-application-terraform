# PostgreSQL Module - main.tf
# Creates Azure PostgreSQL Flexible Server with private networking

resource "azurerm_postgresql_flexible_server" "postgres" {
  name                = var.postgres_server_name
  location            = var.location
  resource_group_name = var.resource_group_name

  # Flexible Server configuration
  sku_name                     = var.sku_name
  version                      = var.postgres_version
  administrator_login          = var.admin_username
  administrator_[REDACTED_GENERIC_PASSWORD_1]      = var.admin_password
  
  # Storage configuration
  storage_mb = var.storage_mb

  # Backup retention
  backup_retention_days = var.backup_retention_days

  # High Availability (Availability Zone redundancy)
  high_availability {
    mode                      = var.high_availability_mode
    standby_availability_zone = var.standby_availability_zone
  }

  # Networking
  delegated_subnet_id = var.delegated_subnet_id

  # SSL enforcement
  ssl_enforce_enabled = var.ssl_enforce

  # Geo-redundant backups
  geo_redundant_backup_enabled = var.geo_redundant_backup

  tags = merge(
    var.common_tags,
    {
      Name = var.postgres_server_name
    }
  )

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres_vnet_link]
}

# Private DNS Zone for PostgreSQL
resource "azurerm_private_dns_zone" "postgres_dns" {
  name                = "postgres.database.azure.com"
  resource_group_name = var.resource_group_name

  tags = merge(
    var.common_tags,
    {
      Name = "postgres-private-dns"
    }
  )
}

# Private DNS Zone Virtual Network Link
resource "azurerm_private_dns_zone_virtual_network_link" "postgres_vnet_link" {
  name                  = "postgres-vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.postgres_dns.name
  virtual_network_id    = var.vnet_id
  resource_group_name   = var.resource_group_name
}

# Firewall rule for virtual network integration
resource "azurerm_postgresql_flexible_server_firewall_rule" "vnet_rule" {
  name             = "allow-vnet"
  server_id        = azurerm_postgresql_flexible_server.postgres.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Database creation
resource "azurerm_postgresql_flexible_server_database" "database" {
  name      = var.database_name
  server_id = azurerm_postgresql_flexible_server.postgres.id
  collation = "en_US.utf8"
  charset   = "UTF8"
}

# PostgreSQL Server Configuration - Connection Pooling
resource "azurerm_postgresql_flexible_server_configuration" "max_connections" {
  name       = "max_connections"
  server_id  = azurerm_postgresql_flexible_server.postgres.id
  value      = var.max_connections
}

# Diagnostic settings for logging
resource "azurerm_monitor_diagnostic_setting" "postgres_diagnostics" {
  count              = var.enable_diagnostics ? 1 : 0
  name               = "${var.postgres_server_name}-diagnostics"
  target_resource_id = azurerm_postgresql_flexible_server.postgres.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "PostgreSQLLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
