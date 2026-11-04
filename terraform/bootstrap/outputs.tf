output "resource_group_name" {
  value = azurerm_resource_group.tfstate.name
}

output "storage_account_name" {
  value = azurerm_storage_account.tfstate.name
}

output "container_name" {
  value = azurerm_storage_container.tfstate.name
}

output "container_scope_id" {
  description = "RBAC scope for the CI identity's Storage Blob Data Contributor"
  value       = azurerm_storage_container.tfstate.id
}
