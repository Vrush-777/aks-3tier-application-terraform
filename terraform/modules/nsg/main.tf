resource "azurerm_network_security_group" "jumpvm" { # this is the network security group resource for jumpvm subnet,
  name                = "${var.prefix}-jumpvm-nsg"   # this is the name of the nsg, it uses the prefix variable to create a unique name for the nsg,
  resource_group_name = var.resource_group           #Create a nsg in the same resource group
  location            = var.location                 #Create a nsg in the same location as the resource group
  tags                = var.tags                     # this is the tags for the nsg, it uses the tags variable to apply tags to the nsg, tags are used for filtering or billing
}

#this is the terraform resource type
resource "azurerm_network_security_rule" "jumpvm_ssh" {                    #this will create network security rule in the jumpvm nsg
  name                        = "Allow-SSH-From-User-IP"                   #it will allow SSH key for from user IP
  priority                    = 100                                        #nsg rules are processed by priority, 100 will allow ur ip
  direction                   = "Inbound"                                  #its a traffic direction, inbound means traffic coming to the jumpvm
  access                      = "Allow"                                    #it will allow the traffic that matches the rule, allow SSH traffic
  protocol                    = "Tcp"                                      #it will allow only TCP traffic coz SSH uses TCP protocol
  source_port_range           = "*"                                        #it means any source port can be used
  destination_port_range      = "22"                                       #it will allow traffic to port 22 which is the default port for SSH
  source_address_prefix       = var.user_public_ip                         #it will allow traffic only from the user public IP
  destination_address_prefix  = "*"                                        #it means traffic can be allowed to any destination IP
  resource_group_name         = var.resource_group                         #Create a nsg rule in the same resource group
  network_security_group_name = azurerm_network_security_group.jumpvm.name # Associate this rule with the jumpvm nsg we created above
}

resource "azurerm_network_security_rule" "allow_vnet_inbound" {
  name      = "Allow-VNet-Inbound"
  priority  = 110
  direction = "Inbound"
  access    = "Allow"
  protocol  = "*"

  source_port_range      = "*"
  destination_port_range = "*"

  source_address_prefix      = "VirtualNetwork"
  destination_address_prefix = "VirtualNetwork"

  resource_group_name         = var.resource_group
  network_security_group_name = azurerm_network_security_group.jumpvm.name
}

resource "azurerm_network_security_rule" "allow_azure_lb" {
  name      = "Allow-AzureLoadBalancer"
  priority  = 120
  direction = "Inbound"
  access    = "Allow"
  protocol  = "*"

  source_port_range      = "*"
  destination_port_range = "*"

  source_address_prefix      = "AzureLoadBalancer"
  destination_address_prefix = "*"

  resource_group_name         = var.resource_group
  network_security_group_name = azurerm_network_security_group.jumpvm.name
}

resource "azurerm_network_security_rule" "jumpvm_no_other_inbound" {
  name                        = "Deny-All-Inbound"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group
  network_security_group_name = azurerm_network_security_group.jumpvm.name
}

output "jumpvm_nsg_id" {
  value = azurerm_network_security_group.jumpvm.id
}
