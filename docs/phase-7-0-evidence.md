# Phase 7.0 evidence - baseline, backup and safety gate

Date: 2026-11-06. Source: `Phase7-0-Baseline-2026-11-06.ps1` and `Phase7-0b-Gaps-2026-11-06.ps1` (both read-only).

## Step / goal

7.0 - prove the starting state before any Phase 7 change: right subscription, clean repo, every root planning as expected, state backed up, guardrails present, prerequisites known.

## Approved design and changed files

No Azure or code changes. One owner-approved GitHub setting change: secret scanning and push protection enabled.

## Expected vs actual

| Root | State | Items | Expected | Actual | Verdict |
|---|---|---|---|---|---|
| terraform\bootstrap | local | 5 | No changes | No changes | Pass |
| terraform\envs\lab | remote | 10 | No changes | No changes | Pass |
| terraform\envs\governance | remote | 14 | No changes | No changes | Pass |
| terraform\envs\probes | local | 21 | No changes | No changes | Pass |
| terraform\envs\policy-lab\governance | local | 3 | No changes | No changes | Pass |
| terraform\envs\policy-lab\workload | local | 1 | 1 to add (denied public IP) | 1 to add, 0 change, 0 destroy | Pass (expected) |

- No unplanned destroy. No drift in any root.
- No stale state lock: every plan acquires the lock, and all six ran with `-lock-timeout=60s` without error.
- lab 10 = 10 managed: hub RG, hub VNet, and `module.spoke["spoke1"|"spoke2"]` x (RG, VNet, hub_to_spoke, spoke_to_hub). Confirmed. No subnets in this root.
- governance 14 = 8 managed (allowed_locations x3, require_tag x3, deny_public_ip x2 on spokes only) + 6 data (3 policy definitions, 3 `data.azurerm_resource_group.scope`). Confirmed.
- bootstrap 5 = 4 managed (RG, storage account, container, `me_state_data` role assignment) + 1 data (`azurerm_client_config`). Confirmed.
- `policy-lab` is not in the reviewed plan's baseline list. It is finished work; its "1 to add" must never be applied.

## Context

| Check | Result |
|---|---|
| Subscription | ce88c049-aaf2-4f55-a832-a41f1535453a (correct) |
| Tenant | 58cfe7a6-945a-4a50-b76b-1b7ec292e33e |
| Branch / last commit | main / 4937d0b (Phase 4 + 3A journal) |
| Uncommitted changes | none |
| Visibility | PUBLIC |
| .gitignore | *.tfstate, *.tfstate.*, *.tfplan, .terraform/ covered |
| Risky files tracked now | none |
| State backups | written outside the repo (path held privately) |

## Guardrails

| RG | lz-* assignments |
|---|---|
| rg-hubspoke-hub-cac | 2 |
| rg-hubspoke-spoke1-cac | 3 |
| rg-hubspoke-spoke2-cac | 3 |

Total 8, matching the design.

## Prerequisites

| Item | Result | Impact |
|---|---|---|
| Microsoft.Network, Storage, KeyVault, Web, ApiManagement, ServiceBus, ManagedIdentity, Insights, OperationalInsights | Registered | none |
| Microsoft.App | **NotRegistered** | Needed for Flex Consumption (7.4C) and possibly for the `snet-func` delegation (7.1B). Must be registered before 7.1B. |
| Flex Consumption in canadacentral | available | none |
| APIM Standard v2 in Canada Central | available (Microsoft Learn region table) | none |

## Cost left running

All four VMs deallocated (3 probe VMs + MyLinux, which is outside the lab). Deallocated VMs still bill for managed disks. Disks, public IPs and budgets listed by gaps script section G.

## Deviations / findings

1. Microsoft.App not registered (see above).
2. Phase 7 plan/design docs are not in the lab repo: tree is clean and the last commit is the Phase 4/3A journal.
3. Repo is already public. Verified by the gaps script: fork PR approval and token defaults pass, history is clean, no branch protection yet (see table).
4. Bootstrap state is local and is the only copy outside the new backup. 7.1C adds UAMIs and RBAC to this root, so its backup matters more from here on. Keep the backup off unencrypted cloud sync (state holds storage account attributes).
5. Max acceptable daily cost not yet stated.

## Gaps script results

| Check | Result | Verdict |
|---|---|---|
| Branch protection / rulesets on main | none / 0 | Gap. Needed before 7.3 (PR + status checks; environment approval). Not needed for 7.1A. |
| Environments | none | Expected. `integration-dev` comes in 7.1C/7.3. |
| Fork PR approval policy | all_external_contributors | Pass |
| Default GITHUB_TOKEN | read; Actions cannot approve PRs | Pass |
| Secret scanning / push protection | was disabled / disabled; **enabled 2026-11-06** (owner-approved GitHub change) | Pass |
| Risky file names in any commit | none | Pass |
| Tracked *.tfvars | none; .gitignore covers .tfvars | Pass |
| History content scan | GitHub secret scanning full-history scan: 0 open alerts | Pass (generic patterns not covered; gitleaks optional) |
| Public IPs | only `MyLinux-ip` (Basic, outside the lab) | Pass for the lab |
| Budgets | `prescription-oauth-lab-budget` 5 annual; `budget-apimlabs-gw-cac` 30 monthly | No landing zone budget yet |
| Managed disks | script quoting bug; rerun separately | Pending |
| Microsoft.App/environments offered as a delegation while NotRegistered | yes | 7.1B delegation likely works; 7.4C still needs registration |

New finding: under the agreed order (lab, then bootstrap, then governance), the integration-dev network RG exists with no policy assignment between 7.1A and 7.1C. It will hold only a VNet and peerings, so risk is low, but it is a guardrail gap. Option: add the network RG to `envs/governance` right after 7.1A, and the workload RG after bootstrap creates it.

## Decisions requested

1. **Microsoft.App registration method.** Option 1: one-time `az provider register --namespace Microsoft.App` by the platform owner, recorded in the journal. Option 2: `azurerm_resource_provider_registration` in bootstrap. Claude recommends option 1: a Terraform destroy of that resource unregisters the provider, which is a bad failure mode for a subscription-wide setting. Timing: after the 7.0 gate, before 7.1B.
2. **policy-lab destroy.** Destroy as its own small step with plan evidence, before 7.1A, so Phase 7 starts from a clean inventory. Or defer. Owner decides. Dependency check done: `git grep` for the RG, definition and assignment names outside `policy-lab` returned nothing.
3. **Daily cost cap.** Shoukat to state a number; used for the budget alert in 7.5B and as the stop rule for leaving APIM/WS1 running.
4. **Commit Phase 7 docs** (`docs/phase-7-plan.md`, `docs/phase-7-design.md`) to the lab repo before 7.1A, as a docs-only PR.
5. ~~Enable secret scanning and push protection~~ Done 2026-11-06; 0 open alerts.
6. **Governance timing for the new network RG:** right after 7.1A, or with the workload RG after 7.1C.
7. **Branch ruleset on main:** record as a 7.3 prerequisite.
8. **Gate verdict: PASS (2026-11-06).** Terraform, state, guardrails, Actions settings, file-name history and secret-scanning history all pass. No STOP condition. Open decisions above do not block 7.1A, except the owner may want the policy-lab destroy done first.
