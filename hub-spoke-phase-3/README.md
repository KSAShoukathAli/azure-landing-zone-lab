# Azure Hub-and-Spoke Lab — Phase 3: A Route Is Not a Router

**Purpose:** Build on your verified Phase 1 and Phase 2 resources, without new VMs, public IPs, Azure Firewall, Bastion, NAT Gateway, or a third Terraform state. Use the **existing hub VM `10.60.1.4`** as a *temporary Linux router* between Spoke 1 `10.61.1.4` and Spoke 2 `10.62.1.4`.

**Important:** This is a learning NVA, not a production firewall. It does not inspect traffic, provide HA, or offer security controls comparable to Azure Firewall. The three existing VMs still incur cost while running.

## Start from your real Azure evidence

Your Phase 2 output showed:

| Source | Destination | Next hop before Phase 3 |
|---|---|---|
| Spoke 1 `10.61.1.4` | Hub `10.60.1.4` | `VirtualNetworkPeering` |
| Spoke 1 `10.61.1.4` | Spoke 2 `10.62.1.4` | `None` (dropped) |
| Hub `10.60.1.4` | Both spoke VNets | `VNetPeering` |

The hub knows the spokes; the spokes have no route **through** the hub to one another.

```text
                HUB VNet 10.60.0.0/16
            +----------------------------+
            | vm-probe-hub-cac           |
            | 10.60.1.4 = Linux router   |
            | Azure NIC forwarding: ON  |
            | Linux ip_forward:    ON   |
            +----------------------------+
                    ^             ^
             UDR    |             |   UDR
           Spoke2   |             |   Spoke1
                    |             |
       Spoke 1      |             |     Spoke 2
      10.61.1.4 ----+             +---- 10.62.1.4

Spoke 1 UDR: 10.62.0.0/16 -> VirtualAppliance 10.60.1.4
Spoke 2 UDR: 10.61.0.0/16 -> VirtualAppliance 10.60.1.4
Peer settings: allow forwarded traffic INTO spokes from hub NVA.
```

**Three different jobs:** A UDR selects the next hop; an Azure NIC flag permits the VM to receive/forward traffic not addressed to itself; the Linux kernel actually forwards the packet. A receiving-side peering setting must also permit forwarded traffic. Return traffic needs its own route. No single switch does all four.

## Before doing anything

This package assumes your existing repository paths are exactly:

- `terraform/envs/lab/main.tf` — Phase 1, owning the **four VNet peering resources**.
- `terraform/envs/probes/main.tf` — Phase 2, owning the **existing hub/spoke probe subnets, NICs, and VMs**.

The `azurerm` provider in your existing labs is `~> 4.0`; this package uses `ip_forwarding_enabled`, the correct 4.x network-interface argument.

**Do not copy the Phase 3 `.tf` files into `terraform/envs/lab`** and do not create an independent third state for the existing hub NIC. All 6 new route-table objects belong in the **existing Phase 2 state**. The peering changes belong in the **existing Phase 1 state**. This prevents two Terraform roots from claiming the same resource.

Save your changes to Git (or back up both `.tfstate` files securely) before the lab. Do **not** commit Terraform state, plan files, secrets, or SSH private keys. Check your Azure subscription and credits. No actual Azure modification occurs during installation or stage selection; only `terraform apply` changes cloud resources.

## 1. Install the additive files and safe patch

Extract this ZIP into your repository root so this file is:

`C:\Users\shouk\Development\lab\azure-landing-zone-lab\hub-spoke-phase-3\README.md`

Open PowerShell in the repository root:

```powershell
Set-Location 'C:\Users\shouk\Development\lab\azure-landing-zone-lab'
az account show --query '{Name:name,Id:id}' -o table
$env:ARM_SUBSCRIPTION_ID = (az account show --query id -o tsv)

.\hub-spoke-phase-3\scripts\Install-Phase3.ps1 -RepoRoot (Get-Location).Path
```

The installer checks that your files resemble the known Phase 1/2 project, makes local backups inside `hub-spoke-phase-3/_backup/`, and performs **only these source-code modifications**:

- Adds `ip_forwarding_enabled = each.key == "hub" && var.phase3_enable_hub_forwarding` to the existing `azurerm_network_interface.probe` resource in Phase 2. It remains **false** initially.
- Adds `phase3.variables.tf`, `phase3.routes.tf` and an initially-off `phase3.auto.tfvars` to `terraform/envs/probes/`.
- Leaves the Phase 1 peering configuration unchanged until Stage 2.

Read the changes before applying:

```powershell
git diff -- terraform/envs/lab/main.tf terraform/envs/probes/main.tf
```

## 2. Stage A — Add ONE route. Predict the result first.

**Question:** If Spoke 1 selects `10.60.1.4` as the next hop for `10.62.1.4`, does that guarantee that Spoke 2 receives the packet? **No.** Azure will send it toward the hub VM, but the hub VM is not yet configured to forward it.

Set Stage 1 (this only edits Terraform files, not Azure):

```powershell
.\hub-spoke-phase-3\scripts\Set-Phase3Stage.ps1 -RepoRoot (Get-Location).Path -Stage 1

Set-Location .\terraform\envs\probes
terraform fmt
terraform validate
terraform plan -out=phase3-a.tfplan
```

**Expected plan for unchanged Phase 2:** 3 add (Spoke 1 route table, route, and association), 0 change, 0 destroy. If Terraform proposes replacing any of your existing VMs, NICs, subnets or peerings: **STOP and investigate**.

```powershell
terraform apply phase3-a.tfplan
Set-Location ..\..\..
.\hub-spoke-phase-3\scripts\Verify-Phase3.ps1
```

**Expected:** Spoke 1 → `10.62.1.4` now reports `VirtualAppliance` with next-hop IP `10.60.1.4`, **instead of** `None`. Spoke 2 → `10.61.1.4` still reports `None`.

**Do not equate “VirtualAppliance next hop” with successful packet delivery.** It only proves a route has been selected. The Linux hub hasn't been enabled as a router and there is no return route yet.

## 3. Stage B — Complete the forward path AND return path

Now we need:

1. **Return route:** Spoke 2 sends `10.61.0.0/16` via `10.60.1.4`.
2. **Azure forwarding:** Enable IP forwarding on the existing hub NIC (`nic-probe-hub-cac`).
3. **Peering permission:** Set `allow_forwarded_traffic=true` on **spoke1_to_hub** and **spoke2_to_hub** (the receiving spoke side of each peering). Do not make new peerings.
4. **Linux forwarding:** Enable `net.ipv4.ip_forward=1` inside the hub VM. This is **not managed by Terraform in this exercise**; the included command uses Azure VM Run Command.

Set Stage 2:

```powershell
Set-Location 'C:\Users\shouk\Development\lab\azure-landing-zone-lab'
.\hub-spoke-phase-3\scripts\Set-Phase3Stage.ps1 -RepoRoot (Get-Location).Path -Stage 2
```

**Apply Phase 1 FIRST** (it owns the peering flags):

```powershell
Set-Location .\terraform\envs\lab
terraform fmt
terraform validate
terraform plan -out=phase3-peering.tfplan
# Expect two peering updates in place; zero resource replacement/destruction.
terraform apply phase3-peering.tfplan
```

**Then apply Phase 2** (it owns the hub NIC and new spoke 2 UDR):

```powershell
Set-Location ..\probes
terraform fmt
terraform validate
terraform plan -out=phase3-b.tfplan
# Expect 3 new resources and 1 NIC update in place; no VM replacement.
terraform apply phase3-b.tfplan

Set-Location ..\..\..
.\hub-spoke-phase-3\scripts\Verify-Phase3.ps1
```

You should see reciprocal VirtualAppliance next hops in the two spoke NIC effective-route tables. Azure hub NIC IP forwarding should display `true`. **But packets may still fail** because the Linux kernel hasn't been configured yet.

## 4. Enable forwarding INSIDE Linux (a separate control)

Try this from the repository root:

```powershell
.\hub-spoke-phase-3\scripts\Enable-GuestForwarding.ps1
```

The included Bash script writes `/etc/sysctl.d/98-hubspoke-lab-forwarding.conf`, enables `net.ipv4.ip_forward`, and adds two temporary, limited Linux forwarding firewall allow rules for the probe IPs. No NAT is performed. Check its output for `Kernel ip_forward: 1`.

**Management-plane caveat:** All your VMs were intentionally created without public IPs or NAT. Azure VM Run Command sometimes fails on private-only VMs because the agent cannot reach required Azure endpoints. If that happens, **STOP**. A failed Run Command is not evidence that the UDR/peering is broken, nor proof that the Linux configuration applied. It may be necessary to establish a controlled private management path or separately reprovision a disposable router VM with boot-time configuration to run this test. Do not open public SSH or attach a public IP simply to bypass the problem.

## 5. Test actual packet delivery (optional if Run Command works)

```powershell
.\hub-spoke-phase-3\scripts\Test-Phase3Packets.ps1
```

**Expected after all forwarding layers work:**

| Probe | Expected |
|---|---|
| Spoke 1 → Hub (`10.60.1.4`) | ICMP replies, baseline |
| Spoke 1 → Spoke 2 (`10.62.1.4`) | ICMP replies **through hub VM** |
| Spoke 2 → Spoke 1 (`10.61.1.4`) | ICMP replies **through hub VM** |

The Run Command can return success even if the **ping** returned a non-zero exit code. Read the ICMP statistics (`3 received`) and the embedded `ping_exit=0`. If you only have Azure effective-route evidence, call the experiment **route-verified**, not packet-delivery-verified.

Troubleshoot in this order: selected next hop → receiving-side peering flag → Azure NIC IP forwarding → Linux `ip_forward` → Linux firewall → return route → guest ICMP response. The full route is bidirectional and must be symmetric for this lab.

## 6. Remove Phase 3 safely, leaving Phases 1 and 2 intact

Reset source configuration to Stage 0:

```powershell
Set-Location 'C:\Users\shouk\Development\lab\azure-landing-zone-lab'
.\hub-spoke-phase-3\scripts\Set-Phase3Stage.ps1 -RepoRoot (Get-Location).Path -Stage 0
```

**Apply Phase 2 FIRST** to remove UDRs and disable Azure NIC forwarding:

```powershell
Set-Location .\terraform\envs\probes
terraform plan -out=phase3-cleanup-probes.tfplan
# Expect destruction of ONLY the 6 Phase 3 route-table objects and hub NIC update.
terraform apply phase3-cleanup-probes.tfplan
```

Then apply Phase 1 to disable forwarded-traffic peering flags:

```powershell
Set-Location ..\lab
terraform plan -out=phase3-cleanup-peering.tfplan
# Expect two peering updates in place; no peering deletion.
terraform apply phase3-cleanup-peering.tfplan
Set-Location ..\..\..
```

The **guest OS** `ip_forward` setting persists inside the hub VM until you disable it or destroy that VM. You can reverse it via Run Command if the agent is accessible, or simply destroy Phase 2's disposable VMs after removing Phase 3 routes. Do not treat Terraform's Stage 0 plan as proof that guest sysctl settings were undone.

**If finished with the whole series**, you can then run `terraform destroy` in `terraform/envs/probes` (Phase 2), followed by `terraform destroy` in `terraform/envs/lab` (Phase 1). **Never destroy Phase 1 while Phase 2 resources still exist.** Keep Terraform state files until destruction is verified.

## The design lesson

A packet `10.61.1.4 → 10.62.1.4` moves through a series of decisions:

1. **Spoke 1 routing** chooses `10.60.1.4` as next hop via UDR.
2. **Peering** delivers it to the hub VNet; the hub NIC is allowed to accept a packet that is **not addressed to the hub VM**.
3. **Linux kernel** actually forwards the packet to Spoke 2 via the hub→Spoke 2 peering.
4. **Spoke 2 receiving peering** permits forwarded traffic originating outside the hub.
5. **Spoke 2 return route** sends the reply to the same hub router, which forwards it back to Spoke 1.

The hub VNet did not become a router. **We deliberately configured a router inside it.** This is the architecture behind centralized inspection designs; a production firewall adds security policy, scaling, HA, telemetry and support boundaries.

## Official reference material

- [Microsoft — Azure virtual network traffic routing](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-udr-overview)
- [Microsoft — VNet peering, forwarded traffic](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-manage-peering)
- [Microsoft — NIC IP forwarding](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-network-interface)
- [Microsoft — Hub-spoke network topology](https://learn.microsoft.com/en-us/azure/networking/design-guide/hub-spoke)
- [HashiCorp — azurerm_network_interface](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface)
- [Microsoft — VM Run Command](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/run-command)
