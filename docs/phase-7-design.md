# Phase 7 technical design: Terraform and pipelines

Companion to `phase-7-plan.md`. The plan says what and why. This says how the code and pipelines are built. Updated 2026-11-05 after review: platform-provisioned subnets, saved plans in a private blob container, runtime storage treated separately.

## 1. Current state (before Phase 7)

| Piece | State |
|---|---|
| Repo | `KSAShoukathAli/azure-landing-zone-lab`, Terraform 1.15.8, azurerm provider ~> 4.0 (4.81.0 in lock files) |
| `terraform/bootstrap` | Local state. Creates `rg-tfstate-cac`, storage `sttfstatecacce88c0` (versioning, soft delete, shared keys off), container `tfstate`, my Blob Data Contributor role |
| `envs/lab` | Remote state `lab.tfstate`. Hub RG and VNet `10.60.0.0/16`. Spokes via `module.spoke` with `for_each` over a `spokes` map (spoke1 `10.61.0.0/16`, spoke2 `10.62.0.0/16`). Spoke-side peerings have `allow_forwarded_traffic = true` |
| `envs/governance` | Remote state `governance.tfstate`. 8 built-in policy assignments at RG scope: allowed locations, required tag `managed_by`, no public IPs in spokes (hub exempt) |
| `envs/probes` | Local state. Subnets, NICs, 3 small VMs (deallocated), UDRs for spoke-to-spoke via a Linux router in the hub |
| `envs/policy-lab/*` | Local state. Finished Phase 2.1 lab, to be destroyed |
| `modules/spoke-network` | RG, VNet, both peering halves. Called with `for_each` |
| CI | `.github/workflows/terraform-plan.yml`: `pull_request` only, matrix `lab`, `governance`. OIDC with `ARM_USE_OIDC`, no secrets. Plan result in the step summary |
| CI identity | App registration `gh-azure-landing-zone-lab-plan`, one federated credential (`pull_request`, immutable subject), Reader on 3 RGs, Blob Data Contributor on the state container |
| Providers | `resource_provider_registrations = "none"` everywhere (identities are RG-scoped) |

## 2. Repository layout after Phase 7

```
terraform/
  bootstrap/
    main.tf, outputs.tf, versions.tf        (existing)
    identity.tf                             NEW: rg-cicd-identity-cac, 2 UAMIs, federated credentials, roles,
                                            "Subnet Join" custom role, empty workload RG rg-intdev-workload-cac,
                                            private tfplans container
  envs/
    lab/
      main.tf                               spokes map gets integration-dev, with subnets
      dns.tf                                NEW: private DNS zones + VNet links
    governance/
      main.tf                               RG map gets integration-dev
    integration-dev/                        NEW workload root
      versions.tf, backend.tf, providers.tf
      variables.tf, locals.tf, data.tf
      keyvault.tf
      storage.tf        Logic App storage, Function storage
      private-endpoints.tf
      servicebus.tf
      logicapp.tf       count = var.deploy_apps ? 1 : 0
      function.tf       count = var.deploy_apps ? 1 : 0
      apim.tf           count = var.deploy_apim ? 1 : 0
      roles.tf          managed identity role assignments
      outputs.tf
      integration-dev.auto.tfvars           deploy_apps, deploy_apim
  modules/
    spoke-network/                          optional subnets input (subnet + NSG + association)
    private-endpoint/                       NEW
.github/workflows/
  terraform-plan.yml                        extended
  terraform-apply-integration-dev.yml       NEW
  terraform-drift.yml                       NEW
.tflint.hcl                                 NEW
.checkov.yaml                               NEW
docs/phase-7-plan.md, docs/phase-7-design.md
```

## 3. Ownership split

| Layer | Root | Owns | Applied by |
|---|---|---|---|
| Platform, network | `envs/lab` | Hub, spoke VNets, peerings, spoke subnets, delegations and NSGs, private DNS zones and links | Platform owner, locally |
| Platform, security | `envs/governance` | Policy assignments | Platform owner, locally |
| Platform, CI identity | `terraform/bootstrap` | State storage, UAMIs, federated credentials, CI roles | Platform owner, locally |
| Workload | `envs/integration-dev` | Everything the integration team runs, in its own RG `rg-intdev-workload-cac`. Joins the platform's subnets | Pipeline, after approval |

Two resource groups per landing zone, as real organizations do: the **network RG** (`rg-hubspoke-integration-dev-cac`, created by the spoke module, holds the VNet and peering) and the **workload RG** (`rg-intdev-workload-cac`). The workload pipeline gets Contributor on its own RG and join-only rights on its subnets, so it can't change the VNet, subnets or peering the platform owns.

Subnets: **the platform provisions them** to the integration team's requirements (prefixes, delegations, private endpoint policies). The first draft had the workload root create subnets with Network Contributor on the VNet, but that role can also change peerings, so it broke the boundary it claimed. NSG rule changes go through a platform PR. That's slower, and it's the price of a clean trust boundary.

## 4. Root by root

### 4.1 `terraform/bootstrap/identity.tf`

- `azurerm_resource_group.cicd` = `rg-cicd-identity-cac`
- `azurerm_user_assigned_identity.plan` = `uami-alz-plan`
- `azurerm_user_assigned_identity.apply_intdev` = `uami-alz-apply-integration-dev`
- `azurerm_federated_identity_credential` x 3:

| Identity | Name | Subject suffix |
|---|---|---|
| plan | `gh-pull-request` | `:pull_request` |
| plan | `gh-main` | `:ref:refs/heads/main` (merge-time plan, nightly drift) |
| apply | `gh-env-integration-dev` | `:environment:integration-dev` |

  Subject prefix: `repo:KSAShoukathAli@275120224/azure-landing-zone-lab@1443587946`. Issuer `https://token.actions.githubusercontent.com`, audience `api://AzureADTokenExchange`.

- Role assignments:

| Identity | Role | Scope |
|---|---|---|
| plan | Reader | hub, spoke1, spoke2, integration-dev network RG, integration-dev workload RG |
| plan | Storage Blob Data Contributor | state container and `tfplans` container |
| apply | Contributor | integration-dev workload RG |
| apply | Role Based Access Control Administrator, with a condition limiting assignable roles to Key Vault Secrets User, Storage Blob Data Owner, Storage Queue Data Contributor, Storage Table Data Contributor, Azure Service Bus Data Sender/Receiver | integration-dev workload RG |
| apply | Private DNS Zone Contributor | each `privatelink.*` zone in the hub RG |
| apply | "Subnet Join" custom role: `Microsoft.Network/virtualNetworks/subnets/read`, `.../subnets/join/action` | each of the four integration-dev subnets (private endpoints and VNet integration need join) |
| apply | Storage Blob Data Contributor | state container |
| apply | Storage Blob Data Reader | `tfplans` container |

- Then: switch GitHub variable `AZURE_CLIENT_ID` to the plan UAMI, add `AZURE_CLIENT_ID_APPLY_INTDEV`, prove CI green, delete the app registration.

Order dependency: the network RG, VNet and zones come from `envs/lab`, so it's applied first and bootstrap reads them with `data` sources. Bootstrap also creates the empty, tagged workload RG, so its role assignments exist before the pipeline's first apply. `envs/integration-dev` then reads that RG with a `data` source instead of creating it.

### 4.2 `envs/lab`

- Spoke module: new optional input `subnets` (map of name to prefix, optional delegation, private endpoint network policies). Creates each subnet, an NSG per subnet and the association. Default `{}`, so spoke1 and spoke2 plan at No changes.
- `spokes` map: add `integration-dev` with `10.63.0.0/22` and the four subnets from the plan. Plan must show only adds: RG, VNet, 2 peerings, 4 subnets, 4 NSGs, 4 associations.
- `dns.tf`:
  - `azurerm_private_dns_zone` for_each over: `privatelink.vaultcore.azure.net`, `privatelink.blob.core.windows.net`, `privatelink.queue.core.windows.net`, `privatelink.table.core.windows.net`, `privatelink.file.core.windows.net`, `privatelink.azurewebsites.net`, `privatelink.azure-api.net`. In the hub RG.
  - `azurerm_private_dns_zone_virtual_network_link` for_each over the product zones x VNets (hub + every `module.spoke`). `registration_enabled = false`.
- One new spoke per PR (each spoke adds a peering on the hub VNet).

### 4.3 `envs/governance`

- Add both integration-dev RGs (network and workload) to the RG map. Both get allowed locations, required tag, no public IPs.
- Watch: private endpoint NICs are created by Azure on the endpoint's behalf. If the required-tag Deny evaluates them without tags, private endpoint creation fails. Test early in 7.2. Fix options: exemption for `Microsoft.Network/networkInterfaces` created by private endpoints, or switch that guardrail to Modify (inherit tag from RG).

### 4.4 `envs/integration-dev` (workload root)

Provider: `resource_provider_registrations = "none"`, `storage_use_azuread = true`, `features { key_vault { purge_soft_delete_on_destroy = false } }`.

Data sources: the workload RG (created by bootstrap), the four subnets (created by `envs/lab`), the DNS zones in the hub RG. Every resource goes in the workload RG.

Locals: name prefix `intdev-cac`, tags `{ managed_by = "terraform", phase = "07", owner = "integration" }`.

| File | Resources |
|---|---|
| `keyvault.tf` | Key Vault: RBAC authorization, public network access off, network ACL default Deny, soft delete 7 days, purge protection off (lab, documented checkov skip) |
| `storage.tf` | Logic App storage: public access off, file share for content via ARM (`azurerm_storage_share` with `storage_account_id`). Runtime storage auth (identity-based vs key) verified against current Logic Apps Standard docs at build time; the content share may still need a key. Function storage: managed identity |
| `private-endpoints.tf` | `module.pe` for_each over a map of ~9 endpoints: target ID, subresource, zone ID |
| `servicebus.tf` | Namespace Standard, `local_auth_enabled = false`, one queue `partner-files` |
| `logicapp.tf` | WS1 plan, `azurerm_logic_app_standard`, VNet integration to `snet-logic`, route all traffic through VNet, public access off, system-assigned identity |
| `function.tf` | Flex Consumption plan and app (`azurerm_function_app_flex_consumption`), VNet integration to `snet-func`, identity-based storage |
| `apim.tf` | APIM Standard v2, VNet integration to `snet-apim`, private endpoint, public access off in a second step, one API with the Logic App as backend |
| `roles.tf` | Logic App identity: Service Bus Data Sender on the queue, Key Vault Secrets User on the vault, storage data roles if identity-based runtime storage works. App authentication and runtime storage authentication are tracked separately |

Toggles in `integration-dev.auto.tfvars`: `deploy_apps` (Logic App plan, Function, APIM), `deploy_apim`. Cost-down is a PR that sets them to false, so the code stays the source of truth.

### 4.5 `modules/private-endpoint`

Inputs: `name`, `resource_group_name`, `location`, `subnet_id`, `target_resource_id`, `subresource`, `private_dns_zone_id`, `tags`. Creates `azurerm_private_endpoint` with one `private_service_connection` (manual approval off) and a `private_dns_zone_group`. Output: private IP. Validation on `subresource` (allowed list).

## 5. Pipelines

### 5.1 Identities per job

| Workflow / job | Trigger | Token subject | Identity |
|---|---|---|---|
| plan (all roots) | `pull_request` | `:pull_request` | plan UAMI |
| apply-intdev / plan | `push` to main | `:ref:refs/heads/main` | plan UAMI |
| apply-intdev / apply | after approval | `:environment:integration-dev` | apply UAMI |
| drift | `schedule`, `workflow_dispatch` | `:ref:refs/heads/main` | plan UAMI |

### 5.2 `terraform-plan.yml` (extended)

- Trigger: `pull_request` to main, paths `terraform/**`, workflow files, `.tflint.hcl`, `.checkov.yaml`.
- Job `checks` (no Azure login): `terraform fmt -check -recursive`, `tflint --init` + `tflint --recursive` (azurerm ruleset), `checkov -d terraform --config-file .checkov.yaml`.
- Job `plan`, needs `checks`, matrix `[lab, governance, integration-dev]`: init, validate, plan `-detailed-exitcode`, summary.
- Permissions: `contents: read`, `id-token: write`. Concurrency per PR.

### 5.3 `terraform-apply-integration-dev.yml` (new)

- Trigger: `push` to main, paths `terraform/envs/integration-dev/**`, `terraform/modules/**`.
- Concurrency: `tf-integration-dev`, `cancel-in-progress: false`.
- Job `plan`: plan UAMI, `terraform plan -out=tfplan`, short summary (resource addresses and counts only), upload `tfplan` to the private `tfplans` blob container as `<run_id>.tfplan` with `az storage blob upload --auth-mode login`.
- Job `apply`: needs `plan`, `environment: integration-dev`, apply UAMI, download the blob by run ID, init, `terraform apply tfplan`. Terraform rejects a stale plan. A lifecycle rule deletes plan blobs after 1 day.
- Why not a workflow artifact: saved plans can hold sensitive values in clear text, and on a public repo anyone signed in to GitHub can download artifacts.

### 5.4 `terraform-drift.yml` (new)

- Trigger: `schedule` nightly (off-peak minute), plus `workflow_dispatch`.
- Matrix: all remote-state roots. Plan UAMI. `plan -detailed-exitcode`.
- Exit 2: open a GitHub issue labeled `drift` (skip if one is already open for that root). Needs `issues: write`.

### 5.5 Quality configs

- `.tflint.hcl`: `plugin "azurerm"` pinned version, `terraform` preset `recommended`.
- `.checkov.yaml`: framework terraform, `soft-fail: false`. Every skip is inline (`#checkov:skip=CKV_...: reason`) next to the resource, never a global skip.

### 5.6 GitHub settings this design needs

- Environment `integration-dev`: required reviewer (me), deployment branches limited to `main`.
- Branch protection on `main`: PR required, `checks` and `plan` required.
- **Repo visibility: public** (decided 2026-11-05). On GitHub Free, required reviewers and branch protection work only on public repos. History scanned for state files, plan files, keys and secrets before the switch. The repo shows the subscription ID and resource names, which is acceptable: the state account has shared keys off. Fork pull requests get no OIDC token and no write permissions, and workflow runs from all external contributors require approval.

## 6. Build order

1. Spoke module `subnets` input (existing spokes: No changes). `envs/lab`: spoke entry with subnets, apply. Then DNS zones and links, apply.
2. `terraform/bootstrap`: identities, federated credentials, custom role, workload RG, `tfplans` container, roles (reads the new subnets and zones), apply.
3. `envs/governance`: add both RGs (they now exist), apply. Guardrails are active before any workload service is created.
4. GitHub variables updated, CI proven green, app registration deleted.
5. `envs/integration-dev`: Key Vault, storage, private endpoints (7.2). First applies local, then through the new pipeline (7.3).
6. Apps (7.4), APIM (7.5).
7. Drift workflow, cost-down PR, journal.

## 7. Test plan

| Test | Expect |
|---|---|
| `nslookup <vault>.vault.azure.net` from hub VM | CNAME to privatelink, A record `10.63.1.x` |
| Same from laptop | Public IP; access denied (public network access off) |
| Same from spoke1 VM | Private IP (zone linked); no connection unless the 1.3 router path is on |
| Logic App URL from the internet | Fails |
| API call through APIM private endpoint from hub VM | 202, message on `partner-files` queue |
| Logic App sends to Service Bus | Works with managed identity. Runtime storage settings documented, including any key the content share needs |
| Apply identity tries to change a peering or subnet | Denied (AuthorizationFailed). Proves the boundary |
| `tfplans` blob from an anonymous or unauthorized caller | Denied |
| PR with a checkov violation | `checks` job fails before any Azure login |
| Merge | Plan saved, job waits for approval, apply uses the saved plan |
| Manual portal change, then nightly run | Drift issue opened |

## 8. Questions

Resolved in review:

- Subnet ownership: the platform provisions subnets; the workload joins them.
- Saved plans: private blob container, not artifacts.
- APIM subnet: /27 for the lab, /24 recommended for production.

Still open, answered during the build:

1. Exactly what Logic Apps Standard runtime storage supports with managed identity, and what the content share still needs.
2. Whether the required-tag Deny blocks private endpoint NICs.
3. Which resources a GitHub-hosted runner fails to plan once public access is off.
4. Whether the constrained RBAC Administrator condition covers every role the apps need.
