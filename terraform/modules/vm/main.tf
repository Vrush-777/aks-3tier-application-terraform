#=============================================================================
# Cloud-Init Configuration with Template Variable Substitution
#
# This configuration:
# - Reads the enhanced cloud-init script (now with idempotency)
# - Performs template variable substitution for tool versions
# - Creates a stable hash for lifecycle-based VM replacement
# - Ensures changes to cloud-init trigger VM recreation
#=============================================================================
locals {
  # Read enhanced cloud-init script
  jumpvm_cloud_init_raw = file("${path.module}/../../scripts/jumpvm-cloud-init-enhanced.yaml")

  # Perform template substitutions
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
  # This hash changes whenever cloud-init content changes,
  # triggering VM replacement via the lifecycle rule below
  jumpvm_cloud_init_hash = base64sha256(local.jumpvm_cloud_init)
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

  #===========================================================================
  # LIFECYCLE: Force VM Replacement When Cloud-Init Changes
  #
  # This lifecycle rule ensures that:
  # 1. Any change to the cloud-init script content triggers VM replacement
  # 2. The VM is destroyed and recreated (not just updated in-place)
  # 3. This guarantees cloud-init runs on a fresh instance
  #
  # The replacement is triggered by changes to:
  # - Tool versions (kubectl_version, kubelogin_version)
  # - Any modification to jumpvm-cloud-init-enhanced.yaml
  #
  # Note: This will destroy existing VM data. Use data volumes if needed.
  #===========================================================================
  lifecycle {
    replace_triggered_by = [
      local.jumpvm_cloud_init_hash
    ]
    ignore_changes = [
      os_disk.storage_account_type  # Allow Azure to optimize storage
    ]
  }
}


#=============================================================================
# Cloud-Init Status Tracking
#
# This data source tracks the bootstrap completion marker file on the Jump VM.
# It's used to determine if cloud-init has completed successfully.
#
# Note: This is informational. The actual bootstrap status should be verified
# by checking for /opt/deploy/.bootstrap-complete on the VM.
#=============================================================================
output "cloud_init_hash" {
  value       = local.jumpvm_cloud_init_hash
  description = "Hash of cloud-init content. Changes trigger VM replacement."
  sensitive   = false
}


output "vm_id" {
  value = azurerm_linux_virtual_machine.jumpvm.id
}
