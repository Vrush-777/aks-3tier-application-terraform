# Managed Identity Module - variables.tf

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "resource_group_id" {
  description = "ID of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "aks_identity_name" {
  description = "Name of the AKS managed identity"
  type        = string
  default     = "aks-identity"
}

variable "appgw_identity_name" {
  description = "Name of the Application Gateway managed identity"
  type        = string
  default     = "appgw-identity"
}

variable "kubelet_identity_name" {
  description = "Name of the Kubelet managed identity"
  type        = string
  default     = "kubelet-identity"
}

variable "acr_id" {
  description = "ID of the Azure Container Registry"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
