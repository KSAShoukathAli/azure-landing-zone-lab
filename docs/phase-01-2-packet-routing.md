# Phase 1.2 - Where Does the Packet Go?

A VM in Spoke 1 sends a packet to the hub, then to Spoke 2. Same subscription, same region, both spokes peered to the hub.
One packet arrives. The other is dropped before it leaves Spoke 1. Why?

Phase 1.1 proved the peerings exist. This phase puts a NIC in each VNet so you can read the route table Azure actually uses.

## What this adds (separate Terraform root: terraform/envs/probes)

| Existing VNet | New subnet | VM | Private IP |
|---|---|---|---|
| Hub | snet-probe-hub, 10.60.1.0/24 | vm-probe-hub-cac | 10.60.1.4 |
| Spoke 1 | snet-probe-spoke1, 10.61.1.0/24 | vm-probe-spoke1-cac | 10.61.1.4 |
| Spoke 2 | snet-probe-spoke2, 10.62.1.0/24 | vm-probe-spoke2-cac | 10.62.1.4 |

9 resources. No public IP, NSG, UDR, firewall, NAT, or new peering.
Phase 1.1 VNets are read with `data` blocks, so destroying this root cannot touch them.

## Run it

```powershell
Set-Location "C:\Users\shouk\Development\lab\azure-landing-zone-lab\terraform\envs\probes"
$env:ARM_SUBSCRIPTION_ID = (az account show --query id -o tsv)
terraform init
terraform fmt -check
terraform validate
terraform plan "-out=phase1-2.tfplan"     # expect 9 to add, 0 change, 0 destroy
terraform apply phase1-2.tfplan
.\scripts\verify-routes.ps1
```

Then confirm the Phase 1.1 root still sees no drift:

```powershell
Set-Location "C:\Users\shouk\Development\lab\azure-landing-zone-lab\terraform\envs\lab"
terraform plan                            # expect: No changes
```

## What to look for in Spoke 1's effective routes

| Prefix | Next hop | Meaning |
|---|---|---|
| 10.61.0.0/16 | VnetLocal | My own VNet |
| 10.60.0.0/16 | VNetPeering | Injected by peer-spoke1-to-hub |
| 10.0.0.0/8 | None | Any other 10.x is dropped |
| 0.0.0.0/0 | Internet | Default |

There is no 10.62.0.0/16 route. So 10.62.1.4 falls into 10.0.0.0/8 -> None. The packet never leaves Spoke 1. The hub never even sees it.

## Explain it in your own words

1. Why does Spoke 1 have a route to 10.60.0.0/16?
2. Why is there no route to 10.62.0.0/16?
3. Would `allow_forwarded_traffic` alone fix it? (No. It is a permission, not a route or a forwarder.)
4. Direct Spoke 1 <-> Spoke 2 peering would work. What do you give up? (Central inspection.)

## Cleanup (same day - VMs cost money)

```powershell
Set-Location "C:\Users\shouk\Development\lab\azure-landing-zone-lab\terraform\envs\probes"
terraform plan -destroy
terraform destroy                         # expect 9 destroyed
Set-Location "C:\Users\shouk\Development\lab\azure-landing-zone-lab"
.\scripts\verify-peerings.ps1             # Phase 1.1 still 4 x Connected
```

Destroy this root before ever destroying Phase 1.1. A VNet with subnets in use cannot be deleted.