output "network_address_spaces" {
  description = "Hub and spoke VNet address spaces."
  value = merge(
    { hub = azurerm_virtual_network.hub.address_space },
    { for k, m in module.spoke : k => m.address_space }
  )
}

output "peering_names" {
  description = "Directional peerings; each hub/spoke pair needs two."
  value = merge(
    { for k, m in module.spoke : "hub_to_${k}" => m.peering_names.hub_to_spoke },
    { for k, m in module.spoke : "${k}_to_hub" => m.peering_names.spoke_to_hub }
  )
}
