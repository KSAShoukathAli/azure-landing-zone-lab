variable "name" {
  description = "Short spoke name, e.g. spoke1. Drives the RG, VNet and peering names."
  type        = string
}

variable "address_space" {
  description = "VNet address space for this spoke."
  type        = list(string)
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "region_code" {
  description = "Short region code used in names."
  type        = string
  default     = "cac"
}

variable "tags" {
  description = "Tags applied to the RG and VNet."
  type        = map(string)
}

variable "hub" {
  description = "The hub this spoke peers with."
  type = object({
    resource_group_name = string
    vnet_name           = string
    vnet_id             = string
  })
}

variable "allow_forwarded_traffic" {
  description = "Spoke side accepts traffic forwarded by the hub router (spoke-to-spoke, Phase 1.3)."
  type        = bool
  default     = true
}
