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

variable "subnets" {
  description = "Optional subnets for this spoke, built by platform to the team's request. Key = short name; the subnet is snet-<key>, the NSG nsg-<spoke>-<key>-<region>."
  type = map(object({
    address_prefix                    = string
    delegation                        = optional(string)
    private_endpoint_network_policies = optional(string, "Disabled")
  }))
  default = {}

  validation {
    condition = alltrue([
      for s in values(var.subnets) :
      contains(["none", "Microsoft.Web/serverFarms", "Microsoft.App/environments"], coalesce(s.delegation, "none"))
    ])
    error_message = "delegation must be Microsoft.Web/serverFarms or Microsoft.App/environments (add new services to local.delegation_actions first)."
  }
}
