variable "resource_group_name" {
  type        = string
  description = "Resource group name for the jump VM."
}

variable "location" {
  type        = string
  description = "Azure region for the jump VM."
}

variable "prefix" {
  type        = string
  description = "Resource name prefix used for the VM."
}

variable "admin_username" {
  type        = string
  description = "Admin username on the jump VM."
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for the jump VM."
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID where the jump VM will be deployed."
}

variable "nsg_id" {
  type        = string
  description = "Network security group ID for the jump VM."
}

variable "vm_size" {
  type        = string
  description = "VM size for the jump VM."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the jump VM."
  default     = {}
}
