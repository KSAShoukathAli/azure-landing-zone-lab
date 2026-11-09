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

output "subnet_ids" {
  description = "Platform-built subnets, per spoke that has any."
  value       = { for k, m in module.spoke : k => m.subnet_ids if length(m.subnet_ids) > 0 }
}

output "private_dns_zone_ids" {
  description = "Private DNS zone IDs by zone name, for private endpoint DNS zone groups (7.2 onward)."
  value       = { for k, z in azurerm_private_dns_zone.this : k => z.id }
}
