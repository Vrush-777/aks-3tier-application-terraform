# Identity variables for Jump VM
# These enable the Jump VM to authenticate to Azure services using Managed Identity

variable "aks_cluster_id" {
  description = "AKS Cluster Resource ID"
  type        = string
}


variable "enable_managed_identity" {
  type        = bool
  description = "Enable System Assigned Managed Identity for the Jump VM"
  default     = true
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
