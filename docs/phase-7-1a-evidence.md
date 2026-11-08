# Phase 7.1A evidence - integration-dev spoke (VNet + peering)

Date: 2026-11-07. Scripts: `Phase7-1A-Change-2026-11-07.ps1`, `Phase7-1A-Apply-2026-11-07.ps1`, `Phase7-1A-Verify-2026-11-07b.ps1`, plus plain `az ... -o table` checks.

## Step / goal

Create the network isolation boundary for the integration team: one new spoke VNet, peered to the hub. No subnets, no services.

## Five questions (short)

1. **Why:** private endpoints and VNet integration need a VNet of the team's own, connected to the hub's shared services.
2. **Rejected:** reusing spoke1/spoke2 (mixes teams), public PaaS only (no private endpoints), a separate subscription (right answer in an enterprise, but one MSDN subscription here, so an RG stands in), a /16 (wasteful), peering to other spokes (a mesh, bypasses the hub).
3. **Interaction:** the hub learns `10.63.0.0/22` over peering. spoke1 and spoke2 do not (not transitive): their `10.63.x` falls into `10/8 None`. No DNS, token or data flow yet. The CI identity needs Reader on the new RG to refresh it.
4. **Failure:** a peering half fails, showing `Initiated` instead of `Connected` (rerun apply). Two hub peering changes at once give `AnotherOperationInProgress` (one spoke per PR). Address overlap is refused (address plan). Bad apply: remove the map entry, plan should show 4 to destroy; state backup as last resort.
5. **Owner:** platform network team, through `envs/lab`, applied by the platform owner. The integration team requests it and cannot change it.

## Approved design and changed files

- `terraform/envs/lab/main.tf`: `"integration-dev" = { address_space = ["10.63.0.0/22"], tags = { phase = "07" } }` and module `tags = merge(local.common_tags, try(each.value.tags, {}))` (decision 2a). Existing spokes pass no tags, so they stay `phase = "01"`.
- PR #4 (branch `phase7-1a-integration-dev-spoke`, commit `8413354`), squash-merged to `main`.

## Expected vs actual plan

| Check | Expected | Actual |
|---|---|---|
| Local plan (branch) | 4 to add, 0 to change, 0 to destroy, all `module.spoke["integration-dev"]` | Match |
| CI `plan (lab)` / `plan (governance)` | pass / pass | pass / pass |
| Saved plan before apply | same 4 | Match |
| Apply | 4 added | `Apply complete! Resources: 4 added, 0 changed, 0 destroyed.` |
| Plan after apply | exit 0 | 0 |
| Items in lab state | 14 | 14 |

## Deployed (sanitized)

| Resource | Value |
|---|---|
| RG | `rg-hubspoke-integration-dev-cac`, canadacentral, tags `managed_by=terraform, phase=07, purpose=landing-zone-lab` |
| VNet | `vnet-integration-dev-cac`, `10.63.0.0/22`, 0 subnets |
| Hub half | `peer-hub-to-integration-dev`: Connected, FullyInSync, forwarded False |
| Spoke half | `peer-integration-dev-to-hub`: Connected, FullyInSync, forwarded True |
| CI app registration roles | Reader on hub, spoke1, spoke2, integration-dev RGs; Storage Blob Data Contributor on `tfstate` container. Nothing at subscription scope |

## Positive tests

- Both new peering halves Connected / FullyInSync (`az network vnet peering list -o table` on both VNets).
- Existing peerings untouched: `peer-hub-to-spoke1` and `peer-hub-to-spoke2` still Connected / FullyInSync, forwarded False.
- Lab plan clean after apply. Outputs list four address spaces and six peerings.

## Negative tests

- Public IPs in the new RG: 0.
- No TCP test: no endpoint exists in the spoke yet. Non-transitive routing is expected by design and not yet proven at packet level.

## Deviations and issues

1. **CI Reader on the new RG, granted outside Terraform** (decision 1a). Temporary. Removed with the app registration in 7.1C, when the plan UAMI gets its roles from bootstrap.
2. **Script bugs (PowerShell 5.1):** an empty JSON list counts as 1, and a JSON array comes back as one object. Hit the apply script's "already present" check and verify sections 3 and 5. Evidence for those items was taken from plain `az ... -o table` output instead. Fix for 7.1B onward: use `-o table`, or `-o tsv` line counts, never `@(ConvertFrom-Json)` counts.
3. Verify section 5 also hit a transient `graph.microsoft.com` timeout (az resolves principal names through Graph). Not a lab issue. The `--all` role list covered the check.

## Cost left running

VNet and peerings: no idle cost (peering is billed per GB transferred). Probe VMs still deallocated.

## Decision requested

Accept 7.1A. Next, 7.1B prerequisites: register `Microsoft.App`; decide whether the new network RG goes into `envs/governance` now or together with the workload RG.
