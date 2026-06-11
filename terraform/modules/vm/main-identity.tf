# Identity and Role Assignment Configuration
# This file adds System Assigned Managed Identity to the Jump VM
# and creates role assignments for AKS cluster access

# Update the azurerm_linux_virtual_machine resource to include identity
# This snippet shows the IDENTITY BLOCK to add to the existing VM resource

# ADD THIS BLOCK to azurerm_linux_virtual_machine "jumpvm":
#   identity {
#     type = "SystemAssigned"
#   }

# ============================================================================
# Role Assignment: AKS Cluster User Role
# ============================================================================
# Allows the Jump VM to authenticate to the AKS cluster using managed identity

resource "azurerm_role_assignment" "jumpvm_aks_user" {
  count                = var.enable_managed_identity ? 1 : 0
  scope                = var.aks_cluster_id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azurerm_linux_virtual_machine.jumpvm.identity[0].principal_id

  depends_on = [azurerm_linux_virtual_machine.jumpvm]
}

# ============================================================================
# Role Assignment: Reader Role on Resource Group
# ============================================================================
# Allows the Jump VM to read resources in the resource group (e.g., get AKS cluster details)

resource "azurerm_role_assignment" "jumpvm_rg_reader" {
  count                = var.enable_managed_identity ? 1 : 0
  scope                = var.resource_group_id
  role_definition_name = "Reader"
  principal_id         = azurerm_linux_virtual_machine.jumpvm.identity[0].principal_id

  depends_on = [azurerm_linux_virtual_machine.jumpvm]
}

# ============================================================================
# Role Assignment: AcrPull Role on ACR
# ============================================================================
# Allows the Jump VM to pull images from the Azure Container Registry

resource "azurerm_role_assignment" "jumpvm_acr_pull" {
  count                = var.enable_managed_identity ? 1 : 0
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_virtual_machine.jumpvm.identity[0].principal_id

  depends_on = [azurerm_linux_virtual_machine.jumpvm]
}
