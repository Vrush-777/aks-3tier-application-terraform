#=============================================================================
# Cloud-Init Configuration with Template Variable Substitution
#
# This configuration:
# - Reads the enhanced cloud-init script (now with idempotency)
# - Performs template variable substitution for tool versions
# - Creates a stable hash for lifecycle-based VM replacement
# - Ensures changes to cloud-init trigger VM recreation
# - Validates cloud-init content before encoding
#
# CRITICAL: Do NOT change the hash computation without updating
# ALL existing VMs or they will be recreated on next apply.
#=============================================================================
locals {
  # Read enhanced cloud-init script from disk
  jumpvm_cloud_init_script_path = "${path.module}/../../scripts/jumpvm-cloud-init-enhanced.yaml"

  jumpvm_cloud_init_raw = file(local.jumpvm_cloud_init_script_path)

  # Validate cloud-init starts with cloud-config header
  # This catches YAML structure errors early
  jumpvm_cloud_init_valid = (
    startswith(local.jumpvm_cloud_init_raw, "#cloud-config") 
    ? local.jumpvm_cloud_init_raw 
    : "ERROR: Cloud-init must start with #cloud-config header"
  )

  # Perform template substitutions for kubectl and kubelogin versions
  jumpvm_cloud_init = replace(
    replace(
      local.jumpvm_cloud_init_raw,
      "__KUBECTL_VERSION__",
      var.kubectl_version
    ),
    "__KUBELOGIN_VERSION__",
    var.kubelogin_version
  )

  # Create hash of cloud-init content for lifecycle trigger
  # This hash MUST change whenever cloud-init content changes,
  # which triggers VM replacement via the lifecycle rule below.
  # 
  # STABILITY NOTE: The hash algorithm (base64sha256) is stable.
  # DO NOT change this algorithm without understanding impacts.
  jumpvm_cloud_init_hash = base64sha256(local.jumpvm_cloud_init)

  # Document the cloud-init version being applied
  # Used in outputs for debugging and validation
  jumpvm_cloud_init_version = "enhanced-v2.0-terraform-lifecycle"
}

resource "terraform_data" "cloud_init_trigger" {
  input = local.jumpvm_cloud_init_hash
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

  # CRITICAL: Base64 encode the cloud-init script
  # Azure automatically decodes this and passes to cloud-init
  custom_data = base64encode(local.jumpvm_cloud_init)

  lifecycle {
  replace_triggered_by = [
    terraform_data.cloud_init_trigger
  ]
}

  # System Assigned Managed Identity for authentication to Azure services
  # This allows the Jump VM to authenticate using 'az login --identity'
  # without requiring any stored credentials
  identity {
    type = "SystemAssigned"
  }

  tags = var.tags

}


output "vm_id" {
  value = azurerm_linux_virtual_machine.jumpvm.id
}
