# Azure Container Registry Module - main.tf
# Creates and configures the container registry

resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  location            = var.location
  resource_group_name = var.resource_group_name

  # Premium SKU enables geo-replication, webhooks, and private links
  sku = var.acr_sku

  # Enable admin access if needed (default: false for security)
  admin_enabled = var.enable_admin_access

  # Enable public network access (set to false for private-only)
  public_network_access_enabled = var.enable_public_network

  tags = merge(
    var.common_tags,
    {
      Name = var.acr_name
    }
  )
}

# Optional: Private Endpoint for Private Link access
resource "azurerm_private_endpoint" "acr_private_endpoint" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "${var.acr_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.acr_name}-connection"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_container_registry.acr.id
    subresource_names              = ["registry"]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.acr_name}-pe"
    }
  )
}

# Optional: Diagnostic Settings for ACR
resource "azurerm_monitor_diagnostic_setting" "acr_diagnostics" {
  count = (
    var.enable_diagnostics &&
    var.log_analytics_workspace_id != ""
  ) ? 1 : 0

  name                       = "${var.acr_name}-diagnostics"
  target_resource_id = azurerm_container_registry.acr.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
