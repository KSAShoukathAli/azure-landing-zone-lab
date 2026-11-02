output "network_address_spaces" {
  description = "The three independently allocated VNet address spaces."
  value = {
    hub    = azurerm_virtual_network.hub.address_space
    spoke1 = azurerm_virtual_network.spoke1.address_space
    spoke2 = azurerm_virtual_network.spoke2.address_space
  }
}

output "peering_names" {
  description = "Four directional peerings; each hub/spoke pair needs two."
  value = {
    hub_to_spoke1 = azurerm_virtual_network_peering.hub_to_spoke1.name
    spoke1_to_hub = azurerm_virtual_network_peering.spoke1_to_hub.name
    hub_to_spoke2 = azurerm_virtual_network_peering.hub_to_spoke2.name
    spoke2_to_hub = azurerm_virtual_network_peering.spoke2_to_hub.name
  }
}