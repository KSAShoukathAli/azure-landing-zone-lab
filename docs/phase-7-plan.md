# Phase 7 plan: dev integration landing zone

Planned 2026-11-05. Build starts 2026-11-06.

## Goal

Build a dev landing zone for an integration team, the way a real organization would: platform pieces in platform roots, workload pieces in a workload root, everything deployed through a pipeline with quality checks.

It covers four open items in one build:

1. Private endpoints and private DNS
2. The apply half of the pipeline (approval, saved plan, apply on merge)
3. Swap the CI identity to user-assigned managed identities, delete the app registration
4. Nightly drift detection

Technical design (Terraform roots, modules, pipelines, identities per job, build order, test plan): see `phase-7-design.md`.

Reviewed with ChatGPT on 2026-11-05. Changes adopted: platform provisions the subnets, saved plans stay out of public artifacts, runtime storage auth treated separately from app auth, APIM subnet sizing marked as lab-only, and the Function's role and the public partner path stated as later work.

## Ownership model

The integration team owns the integration platform, not just apps deployed onto someone else's platform. Owning it doesn't mean owning enterprise infrastructure.

| Component | Owner |
|---|---|
| Management groups, policies, enterprise governance | Central platform / security |
| Hub VNet, shared private DNS zones, enterprise connectivity | Central platform |
| Integration spoke VNet and peering | Central platform |
| Integration subnets, delegations, NSGs | Central platform, provisioned to the integration team's requirements |
| APIM, Service Bus, Logic Apps, Functions | Integration team |
| Key Vault, workload storage, private endpoints, managed identities | Integration team |
| API policies, workflows, Function code, messaging configuration | Integration team |
| Workload Terraform, CI/CD, monitoring, troubleshooting | Integration team |

## How we work

Every step goes through five stages: **Why** (the enterprise problem), **Design** (components and responsibilities), **Implement** (Terraform and Actions, one small step at a time), **Verify** (real Azure behavior, not just a green apply), **Explain** (defend it as an architect).

Every component answers five questions:

1. Why does it exist? What problem does it solve?
2. What alternatives did we reject, and why?
3. How does it interact with everything else? Follow the request, token, DNS lookup, route and data.
4. What happens when it fails? How do we find it and recover?
5. Who owns it in an enterprise? Who deploys, secures, monitors and changes it?

A phase is finished when we understand why it works, not when `terraform apply` succeeds.

## Later phases

- **Phase 8, prescription integration:** Clinic, APIM, ingress Logic App, Service Bus, processing Function, partner API simulator. The Function gets its real job here. Adds OAuth client credentials at APIM, retries, dead-lettering, idempotency, correlation, dashboards and alerts, workflow and Function code deployment, and failure drills (auth, DNS, network, partner down, poison messages).
- **Phase 9, production review:** availability, scaling, disaster recovery, environment separation, deployment strategy, cost, compliance. What changes from the lab and why.
- **Also later:** 3B (split the lab root), Azure Firewall with UDRs, App Gateway WAF as the public partner path, DNS Private Resolver, self-hosted runners, a short Service Bus Premium private endpoint experiment.

## Decisions

| Decision | Choice | Why |
|---|---|---|
| Spoke address | `10.63.0.0/22` | Next after the existing spokes. A /22 is realistic for one landing zone |
| APIM | Standard v2: outbound VNet integration + inbound private endpoint | The modern pattern for new builds. End-to-end isolation without classic injection's management IP, NSG rules and slow deploys. Deploy on a network day, then destroy |
| Service Bus | Standard, managed identity auth, local auth off, no private endpoint | Premium (needed for private endpoints) is about $22 a day. Private endpoints are covered by Key Vault, Storage, Logic App, Function and APIM |
| Functions | Flex Consumption with VNet integration | Near-free when idle |
| Logic App | Standard WS1 | Smallest plan that supports VNet integration. About $6 a day, destroy when idle |
| Private DNS | Zones in the hub RG, linked to hub and every spoke | Same result as a DNS Private Resolver for Azure-only clients. The resolver (about $180 a month per endpoint) is only needed for on-prem |
| Firewall and UDRs | Not in this phase | Cost. Hub-to-spoke traffic works over peering |
| CI apply scope | Workload root only (`envs/integration-dev`) | Platform roots stay plan-in-CI, apply by the platform owner. Real platform/workload split |
| Subnets | Provisioned by the platform in `envs/lab`, through the spoke module, to the integration team's requirements | The workload identity only needs to join subnets. Network Contributor on the VNet would also let it change peerings |
| Saved plans | Stored in a private blob container, not a workflow artifact | Saved plans can hold sensitive values in clear text, and anyone signed in to GitHub can download artifacts from a public repo |
| Repo visibility | Public | Free plan only gives required reviewers and branch protection on public repos. Nothing secret in the repo |
| Partner path (design) | WAF, then APIM, then Logic App | Partners never see the Logic App URL (it carries a SAS signature). APIM owns auth, quotas, versioning |

## Lab vs production

| Piece | Lab | Production |
|---|---|---|
| APIM | Standard v2 | Standard v2, or Premium / Premium v2 for multi-region, zones, self-hosted gateways |
| Logic App plan | WS1, 1 instance | WS2 or WS3, zone-redundant, 3+ instances |
| Service Bus | Standard, public, managed identity | Premium, private endpoint, zone-redundant |
| Storage | LRS | ZRS |
| DNS | Zone links | Zone links + DNS Private Resolver for on-prem |
| Egress | Direct | UDR 0/0 and 10/8 to the hub firewall |
| Ingress | APIM private endpoint, tested from the hub VM. No public partner path yet | App Gateway WAF in the hub, backend = APIM private endpoint |
| APIM integration subnet | /27 (Microsoft's minimum) | /24, Microsoft's recommendation for scaling |

## Address plan

Subnets, delegations and NSGs are created by the platform (`envs/lab`, spoke module `subnets` input), to these requirements from the integration team.

```
vnet-integration-dev-cac     10.63.0.0/22    peered to vnet-hub-cac

  snet-apim    10.63.0.0/27     delegated, APIM Standard v2 outbound VNet integration
  snet-logic   10.63.0.64/26    delegated Microsoft.Web/serverFarms, Logic App outbound
  snet-func    10.63.0.128/26   delegated Microsoft.App/environments, Function (Flex) outbound
  (reserved)   10.63.0.192/26
  snet-pe      10.63.1.0/25     private endpoints, about 9 to start
  (reserved)   10.63.1.128/25, 10.63.2.0/23
```

Private endpoints in `snet-pe`:

| Target | Count | DNS zone |
|---|---|---|
| Key Vault | 1 | `privatelink.vaultcore.azure.net` |
| Logic App storage: blob, queue, table, file | 4 | `privatelink.{blob,queue,table,file}.core.windows.net` |
| Logic App inbound | 1 | `privatelink.azurewebsites.net` |
| Function inbound | 1 | `privatelink.azurewebsites.net` |
| Function storage (blob, more if needed) | 1+ | `privatelink.blob.core.windows.net` |
| APIM inbound | 1 | `privatelink.azure-api.net` |

Check subnet sizes against current Microsoft docs at build time, especially APIM v2 integration and Flex Consumption.

## Where the code lives

| Root | Owner | Phase 7 changes |
|---|---|---|
| `terraform/bootstrap` | Platform | Two user-assigned managed identities, federated credentials, role assignments, a "Subnet Join" custom role, the empty workload RG, a private `tfplans` container |
| `envs/lab` | Platform (network) | One new map entry `integration-dev`, with its subnets, delegations and NSGs. Private DNS zones and VNet links |
| `envs/governance` | Platform (security) | Add the new RG to the guardrail map |
| `envs/integration-dev` (new) | Integration team | Everything in the workload RG: Key Vault, Storage, private endpoints, Logic App, Function, Service Bus, APIM. Joins the platform's subnets |

## Identities

| Identity | Federated subjects | Roles |
|---|---|---|
| `uami-alz-plan` | `pull_request`, `ref:refs/heads/main` (plan on merge + nightly drift) | Reader on hub, spoke1, spoke2 and both integration-dev RGs. Storage Blob Data Contributor on the state and `tfplans` containers |
| `uami-alz-apply-integration-dev` | `environment:integration-dev` only | Contributor on the integration-dev workload RG. Role Based Access Control Administrator on that RG (constrained to the roles the apps need). "Subnet Join" custom role (subnets read and join only) on the four integration-dev subnets. Private DNS Zone Contributor on the zones (private endpoint records). Storage Blob Data Contributor on the state container, Storage Blob Data Reader on `tfplans` |

Two RGs per landing zone: the network RG (VNet, peering, owned by the platform) and the workload RG (everything the team runs). The workload pipeline can't change the VNet or peering.

All subjects use the immutable format: `repo:KSAShoukathAli@275120224/azure-landing-zone-lab@1443587946:...`

## Sessions

### 7.1 Identity and platform prep (item 3)

- Bootstrap: create both UAMIs, federated credentials, roles, the "Subnet Join" custom role, the empty workload RG and the `tfplans` container.
- Switch the `AZURE_CLIENT_ID` variable to the plan UAMI. Open a PR, confirm CI is green. Delete the app registration `gh-azure-landing-zone-lab-plan`.
- Spoke module: add an optional `subnets` input (prefix, delegation, private endpoint policies) that creates each subnet with its NSG. Existing spokes pass nothing, so their plan stays at No changes.
- `envs/lab`: add `integration-dev` with `10.63.0.0/22` and its four subnets. Add the private DNS zones and links.
- `envs/governance`: add both new RGs (network and workload).
- Apply platform roots locally (platform owner), in this order: `envs/lab`, then `bootstrap` (creates the workload RG), then `envs/governance`.

Done when: CI plan is green with the UAMI, the app registration is gone, the new spoke is peered, zones are linked, guardrails apply to the new RG.

### 7.2 Workload root and private endpoints (item 1)

- New root `envs/integration-dev`: backend key `integration-dev.tfstate`, data sources for the workload RG, the platform's subnets and the DNS zones.
- Key Vault (RBAC mode, public access off) + private endpoint.
- Logic App storage account (public access off) + 4 private endpoints.
- Tests from the hub probe VM: Key Vault name resolves to `10.63.1.x`. From the laptop: public answer, then denied. From a spoke1 VM: resolves privately, but no route unless the 1.3 router is on.

Done when: every name resolves to its private IP from the hub, and public access is refused.

### 7.3 Pipeline (item 2)

- Workflow for `envs/integration-dev`: fmt, validate, tflint (azurerm ruleset), checkov, plan, summary on the PR.
- On merge: fresh plan saved to the private `tfplans` blob container (not a workflow artifact), `integration-dev` environment with a required reviewer, apply UAMI downloads and applies the saved plan. One apply at a time. Plan summaries stay short, since logs are public.
- `.tflint.hcl` and a checkov config. Every suppressed check has a written reason.

Done when: a PR shows all checks, merging pauses for approval, approval applies the saved plan.

### 7.4 Apps

- Logic App Standard WS1: VNet integration (`snet-logic`), private storage, inbound private endpoint, public access off. Managed identity with Key Vault Secrets User and Service Bus Data Sender.
- Function on Flex Consumption: VNet integration (`snet-func`), inbound private endpoint, storage via managed identity. Provisioned and smoke-tested only; it joins the business flow in Phase 8.
- Service Bus Standard, local auth off.
- A small workflow: HTTP trigger, then a message on a queue.

Done when: the workflow puts a message on the queue using its managed identity. App-to-service calls (Service Bus, Key Vault) use managed identities. Runtime storage uses whatever Logic Apps Standard supports, verified at build time and documented.

### 7.5 APIM and operations (item 4)

- APIM Standard v2: VNet integration (`snet-apim`), inbound private endpoint, then public access off. One API whose backend is the Logic App.
- Test: the Logic App URL from the internet fails. Through APIM from the hub VM works.
- Nightly drift workflow: plan with `-detailed-exitcode`, open a GitHub issue on exit 2.
- Destroy workflow (manual) for costly resources. Budget alert on the subscription.
- Journal chapter for Phase 7.

Done when: the end-to-end call works only through APIM, drift opens an issue, and the costly resources can be destroyed with one run.

## Problems we expect to hit

1. **The hosted runner can't reach private data planes.** Terraform reads some storage and Key Vault properties over the data plane. With public access off, a GitHub-hosted runner may fail the plan. Decide the fix when it happens: build order, temporary network rules, or a self-hosted runner.
2. **Logic App runtime storage is a separate question from app authentication.** The runtime storage and Azure Files content share have their own requirements, and the content share may still need a key. Follow Microsoft's private-storage deployment order: the content share must be reachable over the VNet before public access goes off. Verify, then document what actually needs a key.
3. **Private endpoint NICs vs the required-tag Deny.** Azure creates the NIC for each private endpoint. If the tag policy evaluates it without tags, private endpoint creation fails. Test early in 7.2.
4. **Repo made public.** On GitHub Free, required reviewers and branch protection only work on public repos, so the repo goes public after a history scan. Fork PRs get no OIDC token; outside contributors need approval to run workflows.
5. **Private endpoint DNS records need rights on the hub zones.** The apply identity needs Private DNS Zone Contributor there. That's a real platform/workload boundary.
6. **checkov findings.** Fix most, suppress a few with a reason (for example, Key Vault purge protection off in a lab).
7. **APIM private endpoint before public access off.** Public access can only be disabled after the private endpoint exists.
8. **Saved plans and logs in a public repo.** Saved plans can hold sensitive values in clear text, and public artifacts are downloadable by anyone signed in to GitHub. Plans go to a private blob container; summaries stay short.
9. **No public partner path in Phase 7.** With APIM public access off and only a private endpoint, internet partners can't reach it. Phase 7 tests from the hub VM. The public path is App Gateway WAF, later.

## Cost

| Running | About |
|---|---|
| Everything except APIM | $8 to $10 a day (mostly the WS1 plan and 9 private endpoints) |
| APIM Standard v2 | about $1 an hour while it exists |
| Idle with apps destroyed | well under $1 a day (zones, Key Vault, storage) |

Rule: destroy the Logic App plan and APIM at the end of each session.
