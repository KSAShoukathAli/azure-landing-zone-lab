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

# 1. Isolated resource group
resource "azurerm_resource_group" "policy_lab" {
  name     = "rg-policy-deny-lab-cac"
  location = "canadacentral"

  tags = {
    managed_by = "terraform"
    purpose    = "policy-deny-lab"
  }
}

# 2. Define the rule (no scope set, so it lives at subscription scope)
resource "azurerm_policy_definition" "deny_public_ip" {
  name         = "deny-public-ip-policy-lab"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Deny Public IP - Isolated Lab"

  policy_rule = jsonencode({
    if = {
      field  = "type"
      equals = "Microsoft.Network/publicIPAddresses"
    }
    then = {
      effect = "deny"
    }
  })
}

# 3. Apply the rule to the isolated RG only
resource "azurerm_resource_group_policy_assignment" "deny_public_ip" {
  name                 = "deny-public-ip-lab"
  resource_group_id    = azurerm_resource_group.policy_lab.id
  policy_definition_id = azurerm_policy_definition.deny_public_ip.id

  display_name = "Deny Public IP - Policy Lab"
}
