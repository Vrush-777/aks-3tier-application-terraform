# Managed Identity Module - main.tf
# Creates managed identities for AKS and other services

# User-Assigned Managed Identity for AKS
resource "azurerm_user_assigned_identity" "aks_identity" {
  name                = var.aks_identity_name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(
    var.common_tags,
    {
      Name = var.aks_identity_name
    }
  )
}

# User-Assigned Managed Identity for Application Gateway
resource "azurerm_user_assigned_identity" "appgw_identity" {
  name                = var.appgw_identity_name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(
    var.common_tags,
    {
      Name = var.appgw_identity_name
    }
  )
}

# User-Assigned Managed Identity for Kubelet
resource "azurerm_user_assigned_identity" "kubelet_identity" {
  name                = var.kubelet_identity_name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(
    var.common_tags,
    {
      Name = var.kubelet_identity_name
    }
  )
}

# RBAC Role Assignment - AKS Identity as Contributor to RG
resource "azurerm_role_assignment" "aks_contributor" {
  scope              = var.resource_group_id
  role_definition_name = "Contributor"
  principal_id       = azurerm_user_assigned_identity.aks_identity.principal_id
}

# RBAC Role Assignment - Application Gateway Identity as Contributor to RG
resource "azurerm_role_assignment" "appgw_contributor" {
  scope              = var.resource_group_id
  role_definition_name = "Contributor"
  principal_id       = azurerm_user_assigned_identity.appgw_identity.principal_id
}

# RBAC Role Assignment - Kubelet Identity for ACR pull
resource "azurerm_role_assignment" "kubelet_acr_pull" {
  scope              = var.acr_id
  role_definition_name = "AcrPull"
  principal_id       = azurerm_user_assigned_identity.kubelet_identity.principal_id
}
