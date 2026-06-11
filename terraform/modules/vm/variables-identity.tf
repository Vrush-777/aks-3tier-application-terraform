# Identity variables for Jump VM
# These enable the Jump VM to authenticate to Azure services using Managed Identity

variable "enable_managed_identity" {
  type        = bool
  description = "Enable System Assigned Managed Identity for the Jump VM"
  default     = true
}

variable "aks_cluster_id" {
  type        = string
  description = "Resource ID of the AKS cluster (needed for role assignment)"
  default     = ""
}

variable "acr_id" {
  type        = string
  description = "Resource ID of the Azure Container Registry (needed for role assignment)"
  default     = ""
}

variable "resource_group_id" {
  type        = string
  description = "Resource ID of the resource group (needed for role assignment)"
  default     = ""
}
