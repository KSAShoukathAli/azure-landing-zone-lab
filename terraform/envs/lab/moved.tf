# Phase 3A: spoke resources moved into modules/spoke-network (for_each).
# Each block renames the address in state. Nothing in Azure changes.

moved {
  from = azurerm_resource_group.spoke1
  to   = module.spoke["spoke1"].azurerm_resource_group.this
}
moved {
  from = azurerm_virtual_network.spoke1
  to   = module.spoke["spoke1"].azurerm_virtual_network.this
}
moved {
  from = azurerm_virtual_network_peering.hub_to_spoke1
  to   = module.spoke["spoke1"].azurerm_virtual_network_peering.hub_to_spoke
}
moved {
  from = azurerm_virtual_network_peering.spoke1_to_hub
  to   = module.spoke["spoke1"].azurerm_virtual_network_peering.spoke_to_hub
}

moved {
  from = azurerm_resource_group.spoke2
  to   = module.spoke["spoke2"].azurerm_resource_group.this
}
moved {
  from = azurerm_virtual_network.spoke2
  to   = module.spoke["spoke2"].azurerm_virtual_network.this
}
moved {
  from = azurerm_virtual_network_peering.hub_to_spoke2
  to   = module.spoke["spoke2"].azurerm_virtual_network_peering.hub_to_spoke
}
moved {
  from = azurerm_virtual_network_peering.spoke2_to_hub
  to   = module.spoke["spoke2"].azurerm_virtual_network_peering.spoke_to_hub
}
