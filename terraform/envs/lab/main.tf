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
}

# 1. Ownership boundaries: one resource group per network.
resource "azurerm_resource_group" "hub" {
  name     = "rg-hubspoke-hub-cac"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_resource_group" "spoke1" {
  name     = "rg-hubspoke-spoke1-cac"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_resource_group" "spoke2" {
  name     = "rg-hubspoke-spoke2-cac"
  location = var.location
  tags     = local.common_tags
}

# 2. Three independent IP address spaces. No subnets or VMs yet.
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-cac"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  address_space       = ["10.60.0.0/16"]
  tags                = local.common_tags
}

resource "azurerm_virtual_network" "spoke1" {
  name                = "vnet-spoke1-cac"
  location            = azurerm_resource_group.spoke1.location
  resource_group_name = azurerm_resource_group.spoke1.name
  address_space       = ["10.61.0.0/16"]
  tags                = local.common_tags
}

resource "azurerm_virtual_network" "spoke2" {
  name                = "vnet-spoke2-cac"
  location            = azurerm_resource_group.spoke2.location
  resource_group_name = azurerm_resource_group.spoke2.name
  address_space       = ["10.62.0.0/16"]
  tags                = local.common_tags
}

# 3. A peering is a directed configuration object.
# For Hub <-> Spoke 1 we need two Azure peering resources.
resource "azurerm_virtual_network_peering" "hub_to_spoke1" {
  name                      = "peer-hub-to-spoke1"
  resource_group_name       = azurerm_resource_group.hub.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke1.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "spoke1_to_hub" {
  name                      = "peer-spoke1-to-hub"
  resource_group_name       = azurerm_resource_group.spoke1.name
  virtual_network_name      = azurerm_virtual_network.spoke1.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false

  # Azure peerings should not be changed in parallel.
  depends_on = [azurerm_virtual_network_peering.hub_to_spoke1]
}

# Hub <-> Spoke 2 is another pair. Do not peer Spoke 1 with Spoke 2.
resource "azurerm_virtual_network_peering" "hub_to_spoke2" {
  name                      = "peer-hub-to-spoke2"
  resource_group_name       = azurerm_resource_group.hub.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke2.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false

  depends_on = [azurerm_virtual_network_peering.spoke1_to_hub]
}

resource "azurerm_virtual_network_peering" "spoke2_to_hub" {
  name                      = "peer-spoke2-to-hub"
  resource_group_name       = azurerm_resource_group.spoke2.name
  virtual_network_name      = azurerm_virtual_network.spoke2.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false

  depends_on = [azurerm_virtual_network_peering.hub_to_spoke2]
}