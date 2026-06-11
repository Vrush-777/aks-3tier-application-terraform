locals {
  jumpvm_cloud_init = replace(
    replace(
      file("${path.module}/../../scripts/jumpvm-cloud-init.yaml"),
      "__KUBECTL_VERSION__",
      var.kubectl_version
    ),
    "__KUBELOGIN_VERSION__",
    var.kubelogin_version
  )
}

resource "azurerm_public_ip" "jump_vm" {
  name                = "${var.prefix}-jumpvm-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "jumpvm" {
  name                = "${var.prefix}-jumpvm-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jump_vm.id
  }
}

resource "azurerm_network_interface_security_group_association" "jumpvm_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.jumpvm.id
  network_security_group_id = var.nsg_id
}

resource "azurerm_linux_virtual_machine" "jumpvm" {
  name                            = "${var.prefix}-jumpvm"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  network_interface_ids           = [azurerm_network_interface.jumpvm.id]
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(local.jumpvm_cloud_init)

  # System Assigned Managed Identity for authentication to Azure services
  identity {
    type = "SystemAssigned"
  }

  tags = var.tags

  lifecycle {
    replace_triggered_by = [terraform_data.jumpvm_cloud_init]
  }
}

resource "terraform_data" "jumpvm_cloud_init" {
  input = sha256(local.jumpvm_cloud_init)
}

output "vm_id" {
  value = azurerm_linux_virtual_machine.jumpvm.id
}
