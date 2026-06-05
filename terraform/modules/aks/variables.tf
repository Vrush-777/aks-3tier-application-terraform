# AKS Module - variables.tf

variable "aks_cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version (e.g., '1.27', '1.28')"
  type        = string
  default     = "1.34.7"
}

variable "default_node_pool_name" {
  description = "Name of the default node pool"
  type        = string
  default     = "systempool"
}

variable "default_node_pool_count" {
  description = "Number of nodes in the default pool"
  type        = number
  default     = 3
}

variable "default_node_pool_vm_size" {
  description = "VM size for default node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "aks_subnet_id" {
  description = "Subnet ID for AKS cluster"
  type        = string
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB"
  type        = number
  default     = 30
}

variable "enable_auto_scaling" {
  description = "Enable auto-scaling for node pool"
  type        = bool
  default     = true
}

variable "min_count" {
  description = "Minimum number of nodes"
  type        = number
  default     = 3
}

variable "max_count" {
  description = "Maximum number of nodes"
  type        = number
  default     = 10
}

variable "availability_zones" {
  description = "Availability zones for node pool"
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "node_labels" {
  description = "Node labels for default pool"
  type        = map(string)
  default     = {}
}

variable "node_taints" {
  description = "Node taints for default pool (key=value:taint-effect)"
  type        = list(string)
  default     = []
}

variable "network_plugin" {
  description = "Network plugin (azure for Azure CNI, kubenet)"
  type        = string
  default     = "azure"
}

variable "network_policy" {
  description = "Network policy (azure, calico)"
  type        = string
  default     = "azure"
}

variable "dns_service_ip" {
  description = "Kubernetes DNS service IP"
  type        = string
  default     = ""
}

# variable "docker_bridge_cidr" {
#   description = "Docker bridge CIDR"
#   type        = string
#   default     = ""
# }

variable "service_cidr" {
  description = "Kubernetes service CIDR"
  type        = string
  default     = ""
}

variable "outbound_type" {
  description = "Outbound type (loadBalancer, userDefinedRouting)"
  type        = string
  default     = "loadBalancer"
}

variable "private_cluster_enabled" {
  description = "Enable private AKS cluster"
  type        = bool
  default     = true
}

variable "private_dns_zone_id" {
  description = "Private DNS zone ID for private cluster"
  type        = string
  default     = ""
}

variable "aks_managed_identity_id" {
  description = "ID of the AKS managed identity"
  type        = string
}

variable "kubelet_client_id" {
  description = "Client ID of kubelet managed identity"
  type        = string
}

variable "kubelet_object_id" {
  description = "Object ID of kubelet managed identity"
  type        = string
}

variable "kubelet_identity_id" {
  description = "ID of kubelet managed identity"
  type        = string
}

variable "admin_group_object_ids" {
  description = "Azure AD group object IDs for admin access"
  type        = list(string)
  default     = []
}

variable "appgw_id" {
  description = "ID of the Application Gateway for AGIC"
  type        = string
}

variable "appgw_name" {
  description = "Name of the Application Gateway"
  type        = string
}

variable "appgw_subnet_cidr" {
  description = "Application Gateway subnet CIDR"
  type        = string
}

variable "appgw_subnet_id" {
  description = "Application Gateway subnet ID"
  type        = string
}

variable "enable_azure_policy" {
  description = "Enable Azure Policy add-on"
  type        = bool
  default     = true
}

variable "automatic_channel_upgrade" {
  description = "Auto-upgrade channel (patch, rapid, stable, node-image)"
  type        = string
  default     = "patch"
}

variable "node_os_channel_upgrade" {
  description = "Node OS upgrade channel (Unmanaged, SecurityPatch, Scheduled, Rapid)"
  type        = string
  default     = "SecurityPatch"
}

variable "enable_maintenance_window" {
  description = "Enable maintenance window"
  type        = bool
  default     = false
}

variable "maintenance_window_day" {
  description = "Maintenance window day of week"
  type        = string
  default     = "Sunday"
}

variable "maintenance_window_duration" {
  description = "Maintenance window duration in hours"
  type        = number
  default     = 4
}

variable "maintenance_window_start_time" {
  description = "Maintenance window start time (HH:MM)"
  type        = string
  default     = "02:00"
}

variable "enable_node_os_maintenance_window" {
  description = "Enable node OS maintenance window"
  type        = bool
  default     = false
}

variable "node_os_maintenance_window_day" {
  description = "Node OS maintenance window day of week"
  type        = string
  default     = "Monday"
}

variable "node_os_maintenance_window_duration" {
  description = "Node OS maintenance window duration in hours"
  type        = number
  default     = 4
}

variable "node_os_maintenance_window_start_time" {
  description = "Node OS maintenance window start time (HH:MM)"
  type        = string
  default     = "02:00"
}

variable "additional_node_pools" {
  description = "Additional node pools configuration"
  type = map(object({
    node_count          = number
    vm_size             = string
    availability_zones  = list(string)
    os_disk_size_gb     = number
    enable_auto_scaling = bool
    min_count           = number
    max_count           = number
    node_labels         = map(string)
    node_taints         = list(string)
    priority            = string # "Regular" or "Spot"
    spot_max_price      = optional(number)
  }))
  default = {}
}

variable "kubelet_role_assignment_id" {
  description = "ID of the kubelet role assignment (for dependency)"
  type        = string
}

variable "aks_role_assignment_id" {
  description = "ID of the AKS role assignment (for dependency)"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
