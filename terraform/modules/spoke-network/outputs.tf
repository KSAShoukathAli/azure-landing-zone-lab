output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "vnet_name" {
  value = azurerm_virtual_network.this.name
}

output "address_space" {
  value = azurerm_virtual_network.this.address_space
}

output "peering_names" {
  value = {
    hub_to_spoke = azurerm_virtual_network_peering.hub_to_spoke.name
    spoke_to_hub = azurerm_virtual_network_peering.spoke_to_hub.name
  }
}

output "subnet_ids" {
  value = { for k, s in azurerm_subnet.this : k => s.id }
}
