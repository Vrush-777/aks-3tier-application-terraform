# Network Module - main.tf
# Creates Virtual Network, subnets, NSGs, and network security rules

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  address_space       = var.address_space
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(
    var.common_tags,
    {
      Name = var.vnet_name
    }
  )
}

# AKS Subnet
resource "azurerm_subnet" "aks_subnet" {
  name                 = var.aks_subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.aks_subnet_address_prefixes

  # Enable service endpoints for security
  service_endpoints = ["Microsoft.KeyVault", "Microsoft.Sql", "Microsoft.Storage"]

  # Enable private endpoint network policies
  private_endpoint_network_policies = "enabled"
}

# Application Gateway Subnet
resource "azurerm_subnet" "appgw_subnet" {
  name                 = var.appgw_subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.appgw_subnet_address_prefixes
}

# Jump VM Subnet
resource "azurerm_subnet" "jumpvm_subnet" {
  name                 = var.jumpvm_subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.jumpvm_subnet_address_prefixes

  service_endpoints = ["Microsoft.KeyVault", "Microsoft.Storage"]
}

# PostgreSQL Delegated Subnet
resource "azurerm_subnet" "postgres_subnet" {
  count                = var.create_postgres_subnet ? 1 : 0
  name                 = var.postgres_subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.postgres_subnet_address_prefixes

  delegation {
    name = "postgres-delegation"

    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }

  private_endpoint_network_policies = "Disabled"
}

# Network Security Group for AKS
resource "azurerm_network_security_group" "aks_nsg" {
  name                = var.aks_nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(
    var.common_tags,
    {
      Name = var.aks_nsg_name
    }
  )
}

# NSG Association for AKS Subnet
resource "azurerm_subnet_network_security_group_association" "aks_nsg_assoc" {
  subnet_id                 = azurerm_subnet.aks_subnet.id
  network_security_group_id = azurerm_network_security_group.aks_nsg.id
}

# Network Security Group for Application Gateway
resource "azurerm_network_security_group" "appgw_nsg" {
  name                = var.appgw_nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(
    var.common_tags,
    {
      Name = var.appgw_nsg_name
    }
  )
}

# NSG Rules for Application Gateway - Allow HTTPS inbound
resource "azurerm_network_security_rule" "appgw_https_inbound" {
  name                        = "AllowHTTPSInbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.appgw_nsg.name
}

# NSG Rules for Application Gateway - Allow HTTP inbound
resource "azurerm_network_security_rule" "appgw_http_inbound" {
  name                        = "AllowHTTPInbound"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.appgw_nsg.name
}

# NSG Rules for Application Gateway - Allow Gateway Manager (required for AGIC)
resource "azurerm_network_security_rule" "appgw_gateway_manager" {
  name                        = "AllowGatewayManager"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"

  source_port_range           = "*"
  destination_port_ranges     = ["65200-65535"]

  source_address_prefix       = "GatewayManager"
  destination_address_prefix  = "*"

  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.appgw_nsg.name
}

# NSG Rules for Application Gateway - Allow Azure Load Balancer (required for AGIC)
resource "azurerm_network_security_rule" "appgw_azure_lb" {
  name                        = "AllowAzureLoadBalancer"
  priority                    = 130
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"

  source_port_range           = "*"
  destination_port_range      = "*"

  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"

  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.appgw_nsg.name
}


# NSG Association for Application Gateway Subnet
resource "azurerm_subnet_network_security_group_association" "appgw_nsg_assoc" {
  subnet_id                 = azurerm_subnet.appgw_subnet.id
  network_security_group_id = azurerm_network_security_group.appgw_nsg.id
}

# Optional: Route Table for AKS (if custom routing needed)
resource "azurerm_route_table" "aks_route_table" {
  count               = var.create_route_table ? 1 : 0
  name                = var.aks_route_table_name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(
    var.common_tags,
    {
      Name = var.aks_route_table_name
    }
  )
}

# Route Table Association for AKS Subnet
resource "azurerm_subnet_route_table_association" "aks_route_assoc" {
  count          = var.create_route_table ? 1 : 0
  subnet_id      = azurerm_subnet.aks_subnet.id
  route_table_id = azurerm_route_table.aks_route_table[0].id
}
