# Azure Landing Zone Lab

Hands-on lab for building an Azure landing zone with Terraform, in a single subscription.
Repo is the source of truth. Work is done with both ChatGPT and Claude; PROGRESS.md keeps them in sync.

## Scope

| Phase | What we build | Skill it proves |
|---|---|---|
| 1 | Hub-and-spoke VNets, peering, NSGs, route tables | Network topology |
| 2 | Management groups + Azure Policy | Governance |
| 3 | Reusable Terraform modules (hub, spoke, governance) | Reusable modules |
| 4 | GitHub Actions: plan on PR, apply on merge, remote state | IaC and CI/CD |
| 5 | Architecture diagram + design decisions | Reference architecture |
| 6 | "How a new app team gets a spoke" guide | Standards and onboarding |

## Address plan

| Network | Address space | Resource group | Purpose |
|---|---|---|---|
| Hub | 10.60.0.0/16 | rg-network-hub-lab | Shared network services |
| Spoke 1 | 10.61.0.0/16 | rg-network-spoke1-lab | Application workload |
| Spoke 2 | 10.62.0.0/16 | rg-network-spoke2-lab | Second application |

Avoids 10.50.0.0/16, used by the APIM networking lab.

## Defaults

- Region: canadacentral
- Tooling: Terraform, Azure CLI (az)
- Cost rule: no Azure Firewall, Bastion, or VPN Gateway left running. VMs only when testing packet flow, then destroy.

## Layout

```
terraform/
  modules/hub-network     hub VNet, subnets, NSGs
  modules/spoke-network   spoke VNet, peering to hub
  modules/governance      management groups, policy assignments
  envs/lab                root module that wires it together
docs/                     design notes, diagrams
scripts/                  helper scripts (az login checks, cleanup)
.github/workflows/        CI/CD pipelines (Phase 4)
```
