# Progress

Paste this file into ChatGPT or Claude when switching between them.

## Current state

- Phase: 1.2 - packet routing probes (code added, not yet applied)
- Next step: apply terraform/envs/probes, read Spoke 1 effective routes, confirm envs/lab shows No changes, then destroy probes

## Phase log

| Date | Phase | What was done | What I proved / learned |
|---|---|---|---|
| 2026-11-02 | 0 | Created repo structure | - |
| 2026-11-02 | 1 | Added Phase 1 Terraform (3 RGs, 3 VNets, 4 peerings) from ChatGPT, reviewed by Claude | - |

| 2026-11-02 | 1.2 | Added probe VMs root (terraform/envs/probes) from ChatGPT Phase 2, reviewed by Claude | - |

## Decisions

- Single MSDN subscription; ownership boundaries simulated with resource groups and modules
- Region canadacentral
- Hub 10.60.0.0/16, Spoke 1 10.61.0.0/16, Spoke 2 10.62.0.0/16

## Open questions

-
- Resource names: rg-hubspoke-{hub,spoke1,spoke2}-cac, vnet-{hub,spoke1,spoke2}-cac
- Phase 1 kept flat in terraform/envs/lab; module refactor is Phase 3
- ChatGPT's network phases are sub-labs of repo Phase 1: 1.1 skeleton, 1.2 packet routing, 1.3 NSGs vs routes, 1.4 spoke-to-spoke via firewall
- Disposable resources get their own Terraform root (envs/probes) so destroy cannot touch the network foundation
- 2026-11-02 1.2 finding: hub NIC has 10.61/16 + 10.62/16 VNetPeering; each spoke has only 10.60/16. Hub knows all routes but does not forward; spoke-to-spoke needs routes on both spokes + a forwarder.
- 2026-11-03 Phase 1.3 (ChatGPT Phase 3): hub VM as Linux router. Stage A = Spoke 1 UDR only; Stage B = return UDR + hub NIC forwarding + spoke peering forwarded flags + guest ip_forward. Helper scripts in hub-spoke-phase-3/.
- 2026-11-03 1.3 Stage A ping test: spoke1->hub 3/3 ttl=64; spoke1->spoke2 0/3; spoke2->spoke1 0/3. Run Command works on private VMs.
- 2026-11-03 1.3 DONE: spoke1<->spoke2 via hub Linux router, 3/3 both ways, ttl=63 (vs 64 direct), ~2.3ms vs ~1.2ms. Failure point moved gate by gate: spoke1 (no route) -> hub NIC (no NIC forwarding) -> hub Linux (ip_forward=0) -> delivered. Next: governance (Azure Policy) or NSGs.
