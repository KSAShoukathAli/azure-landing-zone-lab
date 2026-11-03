output "probe_private_ips" {
  description = "Fixed private IPs for comparing known destinations."
  value       = { for k, v in azurerm_network_interface.probe : k => v.private_ip_address }
}

output "probe_vm_names" {
  value = { for k, v in azurerm_linux_virtual_machine.probe : k => v.name }
}

output "probe_nic_names" {
  value = { for k, v in azurerm_network_interface.probe : k => v.name }
}

output "phase3_udrs" {
  description = "UDRs currently deployed by Phase 3 (empty list = none)."
  value = concat(
    [for r in azurerm_route.phase3_spoke1_to_spoke2 : "spoke1: ${r.address_prefix} -> ${r.next_hop_in_ip_address}"],
    [for r in azurerm_route.phase3_spoke2_to_spoke1 : "spoke2: ${r.address_prefix} -> ${r.next_hop_in_ip_address}"]
  )
}