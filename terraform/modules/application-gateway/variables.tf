# Application Gateway Module - variables.tf

variable "appgw_name" {
  description = "Name of the Application Gateway"
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

variable "appgw_subnet_id" {
  description = "Subnet ID for Application Gateway"
  type        = string
}

variable "appgw_pip_name" {
  description = "Name of the public IP for Application Gateway"
  type        = string
  default     = "appgw-pip"
}

variable "appgw_sku_name" {
  description = "SKU name for Application Gateway (Standard_v2, WAF_v2)"
  type        = string
  default     = "Standard_v2"
}

variable "appgw_tier" {
  description = "Tier of the Application Gateway (Standard_v2, WAF_v2)"
  type        = string
  default     = "Standard_v2"
}

variable "appgw_capacity" {
  description = "Capacity for Application Gateway (1-125)"
  type        = number
  default     = 2

  validation {
    condition     = var.appgw_capacity >= 1 && var.appgw_capacity <= 125
    error_message = "Capacity must be between 1 and 125."
  }
}

variable "appgw_private_ip_address" {
  description = "Private IP address for Application Gateway in the subnet"
  type        = string
  default     = "[REDACTED_IPV4_ADDRESS_1]"
}

variable "tls_enabled" {
  description = "Enable TLS/HTTPS for Application Gateway"
  type        = bool
  default     = false
}

variable "ssl_certificate_path" {
  description = "Path to SSL certificate file (PFX format)"
  type        = string
  default     = ""
}

variable "ssl_certificate_password" {
  description = "Password for SSL certificate"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_waf" {
  description = "Enable Web Application Firewall"
  type        = bool
  default     = false
}

variable "waf_mode" {
  description = "WAF mode (Detection, Prevention)"
  type        = string
  default     = "Prevention"
}

variable "waf_rule_set_type" {
  description = "WAF rule set type (OWASP)"
  type        = string
  default     = "OWASP"
}

variable "waf_rule_set_version" {
  description = "WAF rule set version (3.0, 3.1, 3.2)"
  type        = string
  default     = "3.2"
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
