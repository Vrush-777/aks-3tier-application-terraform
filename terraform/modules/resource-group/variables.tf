# Azure Resource Group Module - variables.tf

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,90}$", var.resource_group_name))
    error_message = "Resource group name must be 1-90 characters and contain only alphanumeric, underscore, or hyphen characters."
  }
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "East US"

  validation {
    condition     = can(regex("^[a-z ]+$", var.location))
    error_message = "Location must be a valid Azure region name."
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "ems"
    CreatedBy   = "terraform"
  }
}
