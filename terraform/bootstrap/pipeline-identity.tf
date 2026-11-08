# Apply identity for the GitHub pipeline (lab root).
# It lives in bootstrap on purpose: bootstrap is applied by the platform owner,
# so the pipeline never grants itself rights.
locals {
  github_repo = "KSAShoukathAli/azure-landing-zone-lab"

  # RGs the lab root owns. The apply identity gets Contributor here and nowhere else.
  lab_apply_rgs = {
    hub               = "rg-hubspoke-hub-cac"
    spoke1            = "rg-hubspoke-spoke1-cac"
    spoke2            = "rg-hubspoke-spoke2-cac"
    "integration-dev" = "rg-hubspoke-integration-dev-cac"
  }
}

resource "azurerm_user_assigned_identity" "gh_lab_apply" {
  name                = "id-gh-lab-apply-cac"
  location            = local.location
  resource_group_name = azurerm_resource_group.tfstate.name
  tags                = merge(local.tags, { purpose = "pipeline-identity" })
}

# Trust only jobs that run in the GitHub environment lab-apply (the one with the approval gate).
# A PR branch or a plain push to main cannot get a token for this identity.
resource "azurerm_federated_identity_credential" "gh_lab_apply" {
  name                      = "github-env-lab-apply"
  user_assigned_identity_id = azurerm_user_assigned_identity.gh_lab_apply.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:${local.github_repo}:environment:lab-apply"
}

# Contributor on the lab RGs: can change resources, cannot assign roles or change policy.
resource "azurerm_role_assignment" "lab_apply_rg" {
  for_each = local.lab_apply_rgs

  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${each.value}"
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.gh_lab_apply.principal_id
  principal_type       = "ServicePrincipal"
}

# Read and lock the remote state.
resource "azurerm_role_assignment" "lab_apply_state" {
  scope                = azurerm_storage_container.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.gh_lab_apply.principal_id
  principal_type       = "ServicePrincipal"
}
