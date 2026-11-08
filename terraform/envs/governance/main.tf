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
  resource_provider_registrations = "none"
  features {}
}

# Phase 2.2 - landing zone guardrails. This root owns ONLY policy assignments.
# Resource group scope because the MSDN subscription is shared with other labs.
# In a real landing zone these would be assigned at a management group.
locals {
  scopes = {
    hub    = "rg-hubspoke-hub-cac"
    spoke1 = "rg-hubspoke-spoke1-cac"
    spoke2 = "rg-hubspoke-spoke2-cac"
    # Phase 7.1A. Network RG for the integration-dev landing zone.
    "integration-dev" = "rg-hubspoke-integration-dev-cac"
  }

  allowed_locations = ["canadacentral"]
  required_tag      = "managed_by"

  # Only spokes are banned from public IPs. The hub is the internet edge (CAF Connectivity).
  spoke_denied_types = ["Microsoft.Network/publicIPAddresses"]
}

# Read-only links to the RGs the lab root owns
data "azurerm_resource_group" "scope" {
  for_each = local.scopes
  name     = each.value
}

# Built-in definitions, looked up by their fixed GUID names
data "azurerm_policy_definition" "allowed_locations" {
  name = "e56962a6-4747-49cd-b67b-bf8b01975c4c" # Allowed locations
}

data "azurerm_policy_definition" "require_tag" {
  name = "871b6d14-10aa-478d-b590-94f262ecfa99" # Require a tag on resources
}

data "azurerm_policy_definition" "not_allowed_types" {
  name = "6c112d4e-5bc7-47ae-a041-ea2d9dccd749" # Not allowed resource types
}

# Guardrail 1: region - hub, spoke1, spoke2
resource "azurerm_resource_group_policy_assignment" "allowed_locations" {
  for_each             = data.azurerm_resource_group.scope
  name                 = "lz-allowed-locations-${each.key}"
  display_name         = "LZ - allowed locations (${each.key})"
  resource_group_id    = each.value.id
  policy_definition_id = data.azurerm_policy_definition.allowed_locations.id

  parameters = jsonencode({
    listOfAllowedLocations = { value = local.allowed_locations }
  })

  non_compliance_message {
    content = "Landing zone standard: deploy only to canadacentral."
  }
}

# Guardrail 2: ownership tag - hub, spoke1, spoke2
resource "azurerm_resource_group_policy_assignment" "require_tag" {
  for_each             = data.azurerm_resource_group.scope
  name                 = "lz-require-tag-${each.key}"
  display_name         = "LZ - require tag ${local.required_tag} (${each.key})"
  resource_group_id    = each.value.id
  policy_definition_id = data.azurerm_policy_definition.require_tag.id

  parameters = jsonencode({
    tagName = { value = local.required_tag }
  })

  non_compliance_message {
    content = "Landing zone standard: every resource needs a managed_by tag."
  }
}

# Guardrail 3: no public IPs - spokes only (hub filtered out)
resource "azurerm_resource_group_policy_assignment" "deny_public_ip" {
  for_each             = { for k, rg in data.azurerm_resource_group.scope : k => rg if k != "hub" }
  name                 = "lz-deny-public-ip-${each.key}"
  display_name         = "LZ - no public IPs (${each.key})"
  resource_group_id    = each.value.id
  policy_definition_id = data.azurerm_policy_definition.not_allowed_types.id

  parameters = jsonencode({
    listOfResourceTypesNotAllowed = { value = local.spoke_denied_types }
  })

  non_compliance_message {
    content = "Landing zone standard: no public IPs in spokes. Internet traffic goes through the hub."
  }
}
