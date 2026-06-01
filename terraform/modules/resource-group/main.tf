# Azure Resource Group Module - main.tf
# Creates the primary resource group for all infrastructure

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location

  tags = merge(
    var.common_tags,
    {
      ManagedBy = "Terraform"
    }
  )
}
