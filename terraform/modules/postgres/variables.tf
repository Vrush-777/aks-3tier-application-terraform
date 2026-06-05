# PostgreSQL Module - variables.tf

variable "postgres_server_name" {
  description = "Name of the PostgreSQL server (must be globally unique, 3-63 characters)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,63}$", var.postgres_server_name))
    error_message = "PostgreSQL server name must be 3-63 lowercase alphanumeric and hyphens, globally unique."
  }
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "sku_name" {
  description = "SKU name (e.g., B_Standard_B1ms, D_Standard_D2s_v3)"
  type        = string
  default     = "B_Standard_B2s"
}

variable "postgres_version" {
  description = "PostgreSQL version (11, 12, 13, 14, 15, 16)"
  type        = string
  default     = "16"

  validation {
    condition     = can(regex("^(11|12|13|14|15|16)$", var.postgres_version))
    error_message = "PostgreSQL version must be one of: 11, 12, 13, 14, 15, 16."
  }
}

variable "admin_username" {
  description = "Administrator username"
  type        = string
  default     = "adminuser"
}

variable "postgres_admin_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
}

variable "storage_mb" {
  description = "Storage size in MB (32768 = 32GB to 1048576 = 1TB)"
  type        = number
  default     = 65536
}

variable "backup_retention_days" {
  description = "Backup retention in days (7-35)"
  type        = number
  default     = 7
}

variable "high_availability_mode" {
  description = "High availability mode (Disabled, ZoneRedundant)"
  type        = string
  default     = "Disabled"
}

variable "standby_availability_zone" {
  description = "Availability zone for standby server"
  type        = string
  default     = "2"
}

variable "delegated_subnet_id" {
  description = "Subnet ID for database delegation"
  type        = string
}

variable "vnet_id" {
  description = "Virtual Network ID for private DNS zone link"
  type        = string
}

variable "ssl_enforce" {
  description = "Enforce SSL connections"
  type        = bool
  default     = true
}

variable "geo_redundant_backup" {
  description = "Enable geo-redundant backups"
  type        = bool
  default     = true
}

variable "database_name" {
  description = "Name of the initial database"
  type        = string
  default     = "employee_db"
}

variable "max_connections" {
  description = "Maximum number of connections"
  type        = number
  default     = 100
}

variable "enable_diagnostics" {
  description = "Enable diagnostic settings"
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID (required if enable_diagnostics is true)"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
