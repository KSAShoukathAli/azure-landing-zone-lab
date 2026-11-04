terraform {
  backend "azurerm" {
    subscription_id      = "ce88c049-aaf2-4f55-a832-a41f1535453a"
    resource_group_name  = "rg-tfstate-cac"
    storage_account_name = "sttfstatecacce88c0"
    container_name       = "tfstate"
    key                  = "governance.tfstate"
    use_azuread_auth     = true
  }
}
