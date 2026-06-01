# Azure Container Registry Module - variables.tf

variable "acr_name" {
  description = "Name of the Azure Container Registry (must be globally unique, 5-50 alphanumeric)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{5,50}$", var.acr_name))
    error_message = "ACR name must be 5-50 lowercase alphanumeric characters and globally unique."
  }
}

variable "location" {
  description = "Azure region for ACR"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "acr_sku" {
  description = "SKU of the container registry (Basic, Standard, Premium)"
  type        = string
  default     = "Premium"

  validation {
    condition     = can(regex("^(Basic|Standard|Premium)$", var.acr_sku))
    error_message = "ACR SKU must be one of: Basic, Standard, Premium."
  }
}

variable "enable_admin_access" {
  description = "Enable admin user access to ACR"
  type        = bool
  default     = false
}

variable "enable_public_network" {
  description = "Enable public network access to ACR"
  type        = bool
  default     = true
}

variable "enable_private_endpoint" {
  description = "Create a private endpoint for ACR"
  type        = bool
  default     = false
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID for private endpoint (required if enable_private_endpoint is true)"
  type        = string
  default     = ""
}

variable "enable_diagnostics" {
  description = "Enable diagnostic settings for ACR"
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for diagnostics (required if enable_diagnostics is true)"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
