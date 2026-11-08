locals {
  rg_name   = "rg-hubspoke-${var.name}-${var.region_code}"
  vnet_name = "vnet-${var.name}-${var.region_code}"

  # Actions Azure attaches to each delegation. Stated here so re-plans stay at No changes.
  delegation_actions = {
    "Microsoft.Web/serverFarms"  = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.App/environments" = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
  }
}

# One RG per spoke: the landing zone's ownership boundary.
resource "azurerm_resource_group" "this" {
  name     = local.rg_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "this" {
  name                = local.vnet_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = var.address_space
  tags                = var.tags
}

# Hub half of the handshake. It lives on the hub VNet, but the spoke module
# creates it, so one module call gives a fully connected landing zone.
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "peer-hub-to-${var.name}"
  resource_group_name       = var.hub.resource_group_name
  virtual_network_name      = var.hub.vnet_name
  remote_virtual_network_id = azurerm_virtual_network.this.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# Spoke half. Waits for the hub half: Azure locks a VNet while a peering changes.
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "peer-${var.name}-to-hub"
  resource_group_name       = azurerm_resource_group.this.name
  virtual_network_name      = azurerm_virtual_network.this.name
  remote_virtual_network_id = var.hub.vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = var.allow_forwarded_traffic
  allow_gateway_transit        = false
  use_remote_gateways          = false

  depends_on = [azurerm_virtual_network_peering.hub_to_spoke]
}

# Phase 7.1B. Optional subnets. Platform builds them; the workload team only joins them.
resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                              = "snet-${each.key}"
  resource_group_name               = azurerm_resource_group.this.name
  virtual_network_name              = azurerm_virtual_network.this.name
  address_prefixes                  = [each.value.address_prefix]
  private_endpoint_network_policies = each.value.private_endpoint_network_policies

  dynamic "delegation" {
    for_each = each.value.delegation == null ? [] : [each.value.delegation]
    content {
      name = "delegation"
      service_delegation {
        name    = delegation.value
        actions = local.delegation_actions[delegation.value]
      }
    }
  }
}

# One NSG per subnet. Carries the module tags: require-tag (managed_by) is Deny on this RG.
resource "azurerm_network_security_group" "this" {
  for_each = var.subnets

  name                = "nsg-${var.name}-${each.key}-${var.region_code}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = var.subnets

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}
