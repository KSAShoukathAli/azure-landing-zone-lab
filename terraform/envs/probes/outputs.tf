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

output "what_this_phase_does_not_create" {
  value = "No public IP, firewall, NAT gateway, Bastion, NSG, UDR, or new VNet peering"
}