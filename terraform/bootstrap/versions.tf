terraform {
  required_version = ">= 1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  # No backend block on purpose. This root creates the state storage,
  # so its own state stays local.
}

provider "azurerm" {
  features {}
  subscription_id     = "ce88c049-aaf2-4f55-a832-a41f1535453a"
  storage_use_azuread = true
}
