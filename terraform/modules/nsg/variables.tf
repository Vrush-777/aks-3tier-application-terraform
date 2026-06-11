variable "prefix" { #it will ask for prefix when we run terraform apply, this prefix will be used in naming the resources like nsg
  type        = string
  description = "Resource name prefix used for NSG naming."
}

variable "resource_group" { #it will ask for resource group name when we run terraform apply
  type        = string
  description = "Resource group name where NSGs will be created."
}

variable "location" { #it will ask for location when we run terraform apply
  type        = string
  description = "Azure region for NSG creation."
}
#it will ask for user public IP when we run terraform apply, this IP will be used in the NSG rule to allow SSH traffic only from this IP
variable "user_public_ip" {
  type        = string
  description = "Source CIDR for the jump host SSH rule."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to NSG resources."
  default     = {}
}
