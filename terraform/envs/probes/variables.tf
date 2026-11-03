variable "ssh_public_key_path" {
  description = "Path to an existing SSH PUBLIC key on your Windows workstation; no private key goes into Terraform state."
  type        = string
  default     = "~/.ssh/azure-hub-spoke-lab.pub"
}

variable "vm_size" {
  description = "Small lab VM size. If B1s is unavailable in Canada Central, try Standard_B1ms."
  type        = string
  default     = "Standard_B1s"
}