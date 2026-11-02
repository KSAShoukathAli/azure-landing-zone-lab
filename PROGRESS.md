# Progress

Paste this file into ChatGPT or Claude when switching between them.

## Current state

- Phase: 1 - network skeleton (code added, not yet applied)
- Next step: terraform plan/apply in terraform/envs/lab, then scripts/verify-peerings.ps1

## Phase log

| Date | Phase | What was done | What I proved / learned |
|---|---|---|---|
| 2026-11-02 | 0 | Created repo structure | - |
| 2026-11-02 | 1 | Added Phase 1 Terraform (3 RGs, 3 VNets, 4 peerings) from ChatGPT, reviewed by Claude | - |

## Decisions

- Single MSDN subscription; ownership boundaries simulated with resource groups and modules
- Region canadacentral
- Hub 10.60.0.0/16, Spoke 1 10.61.0.0/16, Spoke 2 10.62.0.0/16

## Open questions

-
- Resource names: rg-hubspoke-{hub,spoke1,spoke2}-cac, vnet-{hub,spoke1,spoke2}-cac
- Phase 1 kept flat in terraform/envs/lab; module refactor is Phase 3
