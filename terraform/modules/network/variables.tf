# Network Module - variables.tf

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
}

variable "address_space" {
  description = "Address space for the virtual network (CIDR)"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "aks_subnet_name" {
  description = "Name of the AKS subnet"
  type        = string
  default     = "aks-subnet"
}

variable "aks_subnet_address_prefixes" {
  description = "Address prefixes for AKS subnet"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "appgw_subnet_name" {
  description = "Name of the Application Gateway subnet"
  type        = string
  default     = "appgw-subnet"
}

variable "appgw_subnet_address_prefixes" {
  description = "Address prefixes for Application Gateway subnet"
  type        = list(string)
  default     = ["10.1.2.0/24"]
}

variable "postgres_subnet_name" {
  description = "Name of the PostgreSQL delegated subnet"
  type        = string
  default     = "postgres-subnet"
}

variable "postgres_subnet_address_prefixes" {
  description = "Address prefixes for PostgreSQL subnet"
  type        = list(string)
  default     = ["10.1.3.0/24"]
}

variable "create_postgres_subnet" {
  description = "Whether to create a dedicated PostgreSQL subnet"
  type        = bool
  default     = true
}

variable "aks_nsg_name" {
  description = "Name of the AKS Network Security Group"
  type        = string
  default     = "aks-nsg"
}

variable "appgw_nsg_name" {
  description = "Name of the Application Gateway Network Security Group"
  type        = string
  default     = "appgw-nsg"
}

variable "create_route_table" {
  description = "Whether to create a route table for AKS subnet"
  type        = bool
  default     = false
}

variable "aks_route_table_name" {
  description = "Name of the AKS route table"
  type        = string
  default     = "aks-route-table"
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
