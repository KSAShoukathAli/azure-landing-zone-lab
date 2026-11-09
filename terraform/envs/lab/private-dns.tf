# Phase 7.1B PR 2. Private DNS zones for private endpoints.
# Platform owns them in the hub RG (one copy for all landing zones).
# Each zone is linked to the VNets that must resolve private endpoint names.
locals {
  private_dns_zones = toset([
    "privatelink.vaultcore.azure.net",    # Key Vault
    "privatelink.blob.core.windows.net",  # Storage blob
    "privatelink.queue.core.windows.net", # Storage queue
    "privatelink.table.core.windows.net", # Storage table
    "privatelink.file.core.windows.net",  # Storage file (Logic App Standard content share)
    "privatelink.azurewebsites.net",      # Logic App / Function inbound
    "privatelink.azure-api.net",          # APIM v2 inbound
  ])

  # VNets that get a link to every zone. spoke1/spoke2 left out on purpose (decision 2026-11-08).
  private_dns_link_vnets = {
    hub               = azurerm_virtual_network.hub.id
    "integration-dev" = module.spoke["integration-dev"].vnet_id
  }

  private_dns_links = {
    for pair in setproduct(keys(local.private_dns_link_vnets), local.private_dns_zones) :
    "${pair[0]}:${pair[1]}" => { vnet = pair[0], zone = pair[1] }
  }
}

resource "azurerm_private_dns_zone" "this" {
  for_each = local.private_dns_zones

  name                = each.value
  resource_group_name = azurerm_resource_group.hub.name
  tags                = local.common_tags
}

# registration_enabled = false: VMs do not auto-register; only private endpoints write records.
resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = local.private_dns_links

  name                  = "link-${each.value.vnet}"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = azurerm_private_dns_zone.this[each.value.zone].name
  virtual_network_id    = local.private_dns_link_vnets[each.value.vnet]
  registration_enabled  = false
  tags                  = local.common_tags
}
