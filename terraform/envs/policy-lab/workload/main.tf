terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Read-only link to the RG the governance root owns (a GET, not managed here)
data "azurerm_resource_group" "policy_lab" {
  name = "rg-policy-deny-lab-cac"
}

# The resource the policy should block
resource "azurerm_public_ip" "should_be_denied" {
  name                = "pip-should-be-denied-cac"
  resource_group_name = data.azurerm_resource_group.policy_lab.name
  location            = data.azurerm_resource_group.policy_lab.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    managed_by = "terraform"
    purpose    = "policy-deny-test"
  }
}
