# Application Gateway Module - main.tf
# Creates and configures the Application Gateway with AGIC support

# Public IP for Application Gateway
resource "azurerm_public_ip" "appgw_pip" {
  name                = var.appgw_pip_name
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(
    var.common_tags,
    {
      Name = var.appgw_pip_name
    }
  )
}

# Application Gateway
resource "azurerm_application_gateway" "appgw" {
  name                = var.appgw_name
  location            = var.location
  resource_group_name = var.resource_group_name

  sku {
    name     = var.appgw_sku_name
    tier     = var.appgw_tier
    capacity = var.appgw_capacity
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = var.appgw_subnet_id
  }

  # Frontend IP Configuration - Public
  frontend_ip_configuration {
    name                 = "public-frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }

  # Frontend IP Configuration - Private (for AGIC)
  frontend_ip_configuration {
    name              = "private-frontend-ip"
    subnet_id         = var.appgw_subnet_id
    private_ip_address = var.appgw_private_ip_address
    private_ip_address_allocation = "Static"
  }

  # Frontend Port - HTTP
  frontend_port {
    name = "http-frontend-port"
    port = 80
  }

  # Frontend Port - HTTPS (optional, configured if tls_enabled)
  frontend_port {
    name = "https-frontend-port"
    port = 443
  }

  # Backend Address Pool (empty initially, populated by AGIC)
  backend_address_pool {
    name = "backend-pool"
  }

  # HTTP Settings
  backend_http_settings {
    name                  = "http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
    host_name             = ""
  }

  # HTTP Request Routing Rule
  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "public-frontend-ip"
    frontend_port_name             = "http-frontend-port"
    protocol                       = "Http"
  }

  # Request Routing Rule
  request_routing_rule {
    name                       = "http-routing-rule"
    priority                   = 9
    rule_type                  = "PathBased"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "backend-pool"
    backend_http_settings_name = "http-settings"
  }

  # Optional: HTTPS listener and rule
  dynamic "http_listener" {
    for_each = var.tls_enabled ? [1] : []
    content {
      name                           = "https-listener"
      frontend_ip_configuration_name = "public-frontend-ip"
      frontend_port_name             = "https-frontend-port"
      protocol                       = "Https"
      ssl_certificate_name           = "appgw-cert"
    }
  }

  # Optional: HTTPS SSL Certificate
  dynamic "ssl_certificate" {
    for_each = var.tls_enabled && var.ssl_certificate_path != "" ? [1] : []
    content {
      name                = "appgw-cert"
      data                = filebase64(var.ssl_certificate_path)
      password            = var.ssl_certificate_password
    }
  }

  # Enable WAF (optional)
  dynamic "waf_configuration" {
    for_each = var.enable_waf ? [1] : []
    content {
      enabled            = true
      firewall_mode      = var.waf_mode
      rule_set_type      = var.waf_rule_set_type
      rule_set_version   = var.waf_rule_set_version
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name = var.appgw_name
    }
  )

  depends_on = [azurerm_public_ip.appgw_pip]

  lifecycle {
    ignore_changes = [
      backend_address_pool,
      backend_http_settings,
      frontend_port,
      http_listener,
      request_routing_rule,
      url_path_map,
      redirect_configuration
    ]
  }
}

# Diagnostic Settings for Application Gateway
resource "azurerm_monitor_diagnostic_setting" "appgw_diagnostics" {
  count              = var.enable_diagnostics ? 1 : 0
  name               = "${var.appgw_name}-diagnostics"
  target_resource_id = azurerm_application_gateway.appgw.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  enabled_log {
    category = "ApplicationGatewayPerformanceLog"
  }

  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
