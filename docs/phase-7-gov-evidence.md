# Phase 7 evidence - guardrails on the integration-dev network RG

Date: 2026-11-07. Done after 7.1A, before 7.1B (owner decision: close the guardrail gap early instead of waiting for 7.1C). Scripts: `Phase7-Gov-Change/Apply/Verify-2026-11-07.ps1`.

Also done today: `Microsoft.App` registered (`az provider register --namespace Microsoft.App --wait`, state `Registered`), the one-time platform-owner action recorded for 7.1B and 7.4C.

## Five questions (short)

1. **Why:** since 7.1A the new RG had no rules; anything could land there in any region, untagged, or with a public IP.
2. **Rejected:** subscription scope (MSDN subscription is shared with other labs), waiting for 7.1C (longer gap, and 7.1B creates NSGs here), management group scope (no MG hierarchy in this lab), custom definitions (built-ins cover it).
3. **Interaction:** no traffic or DNS. Resource Manager judges every create or update in the RG. Subnets and peerings can't hold tags, so the tag rule skips them. CI reads the RG through a data source, which works because of the 7.1A Reader grant.
4. **Failure:** a legitimate deploy gets `RequestDisallowedByPolicy`; fix the code (add the tag) or change the rule through a governance PR. Rollback: remove the map entry, plan shows 3 to destroy.
5. **Owner:** platform security, `envs/governance`, applied by the platform owner. The integration team sees denials and can't change or exempt them.

## Change

`terraform/envs/governance/main.tf`: `"integration-dev" = "rg-hubspoke-integration-dev-cac"` added to `local.scopes`. PR #5, squash commit `41db08f`.

## Expected vs actual

| Check | Expected | Actual |
|---|---|---|
| Local plan, CI plan | 3 to add, all `["integration-dev"]` | Match (CI both checks green) |
| Saved plan before apply | same 3 | Match |
| Apply | 3 added | `Apply complete! Resources: 3 added` (about 1m40s each, global policy replication) |
| Plan after apply | exit 0 | 0 |
| Governance state | 18 items (11 managed + 7 data) | 18 |

## Tests (about 5 minutes after apply)

| Test | Attempt | Expected | Result |
|---|---|---|---|
| A | Standard public IP, tagged | DENIED | DENIED (RequestDisallowedByPolicy) |
| B | Route table in eastus, tagged | DENIED | DENIED |
| C | Route table in canadacentral, no tag | DENIED | DENIED |
| D | Route table in canadacentral, tagged (control) | ALLOWED | ALLOWED, created then deleted |

Leftovers in the RG: only `vnet-integration-dev-cac`. Assignments listed: `lz-allowed-locations-integration-dev`, `lz-require-tag-integration-dev`, `lz-deny-public-ip-integration-dev`.

## Deviations and issues

1. Order changed from the reviewed plan (governance for the network RG now, not in 7.1C). Owner-approved. The workload RG is still added in 7.1C, after bootstrap creates it.
2. The verify script did not capture the rule name in the denial (az's error text didn't contain the `lz-` name the regex looked for). Each test breaks exactly one rule, so the attribution holds. Fix for later tests: match on the display name `LZ - ...`.

## Carry-forward for 7.1B

NSGs created in this RG must carry the `managed_by` tag or the Deny blocks them. The spoke module change must pass `var.tags` to the NSGs.

## Cost left running

None added. Policy assignments are free.
