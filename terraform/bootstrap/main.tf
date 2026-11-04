locals {
  location       = "canadacentral"
  rg_name        = "rg-tfstate-cac"
  sa_name        = "sttfstatecacce88c0"
  container_name = "tfstate"
  tags = {
    managed_by = "terraform"
    purpose    = "terraform-state"
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "tfstate" {
  name     = local.rg_name
  location = local.location
  tags     = local.tags
}

resource "azurerm_storage_account" "tfstate" {
  name                            = local.sa_name
  resource_group_name             = azurerm_resource_group.tfstate.name
  location                        = local.location
  account_kind                    = "StorageV2"
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  tags = local.tags
}

# storage_account_id (not storage_account_name) makes the container ID an ARM ID,
# which is a valid RBAC scope.
resource "azurerm_storage_container" "tfstate" {
  name                  = local.container_name
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

# You, for running migrate-state and local plans with Entra auth.
resource "azurerm_role_assignment" "me_state_data" {
  scope                = azurerm_storage_container.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}
