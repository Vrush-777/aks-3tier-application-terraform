# ============================================================================
# Jump VM Configuration Variables
# ============================================================================
# These variables configure the Jump VM for private AKS deployment

variable "jumpvm_admin_username" {
  type        = string
  description = "Admin username for the Jump VM"
  default     = "azureuser"
  sensitive   = false
}

variable "jumpvm_ssh_public_key" {
  type        = string
  description = "SSH public key for Jump VM authentication"
  default     = ""
  sensitive   = true
  # This should be provided via terraform.tfvars or environment variable
  # TF_VAR_jumpvm_ssh_public_key
}

# variable "jumpvm_ssh_public_key_path" {
#   type        = string
#   description = "Local SSH public key path used when jumpvm_ssh_public_key is not provided."
#   default     = "~/.ssh/id_rsa.pub"
# }

variable "jumpvm_vm_size" {
  type        = string
  description = "VM size for the Jump VM (e.g., Standard_B2s for dev, Standard_D2s_v3 for prod)"
  default     = "Standard_D2s_v3"
}

variable "jumpvm_ssh_source_address_prefix" {
  type        = string
  description = "Source address prefix allowed to SSH into the Jump VM."
  default     = "*"
}
