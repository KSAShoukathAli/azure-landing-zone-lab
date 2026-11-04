terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Uses your Azure CLI login. Set ARM_SUBSCRIPTION_ID in your shell first.
provider "azurerm" {
  resource_provider_registrations = "none"
  features {}
}

variable "location" {
  description = "Azure region for the three VNets."
  type        = string
  default     = "canadacentral"
}

locals {
  common_tags = {
    purpose    = "landing-zone-lab"
    managed_by = "terraform"
    phase      = "01"
  }

  hub = {
    resource_group_name = azurerm_resource_group.hub.name
    vnet_name           = azurerm_virtual_network.hub.name
    vnet_id             = azurerm_virtual_network.hub.id
  }

  # Landing zones. A new spoke is one new entry here.
  # Add one spoke per PR: each spoke adds a peering on the hub VNet, and Azure
  # rejects overlapping peering changes. For a full rebuild: apply -parallelism=1.
  spokes = {
    spoke1 = { address_space = ["10.61.0.0/16"] }
    spoke2 = { address_space = ["10.62.0.0/16"] }
  }
}

# Hub: owned by the platform network team. Stays in this root.
resource "azurerm_resource_group" "hub" {
  name     = "rg-hubspoke-hub-cac"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-cac"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  address_space       = ["10.60.0.0/16"]
  tags                = local.common_tags
}

# Spokes: one module, one instance per landing zone. Never peer spoke to spoke.
module "spoke" {
  source   = "../../modules/spoke-network"
  for_each = local.spokes

  name          = each.key
  address_space = each.value.address_space
  location      = var.location
  tags          = local.common_tags
  hub           = local.hub
}
