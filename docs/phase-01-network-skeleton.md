# Phase 1 - The Network Skeleton

Two application teams need Azure networking. Neither should own the shared connectivity.
So you build a hub VNet for future shared services, and one spoke per team.
Each VNet is separate. Peering connects each spoke to the hub. The hub VNet by itself is not a router or a firewall.

```text
                 Single Visual Studio / MSDN subscription - Canada Central

                         vnet-hub-cac
                         10.60.0.0/16
                          /        \
            2 peerings   /          \   2 peerings
                        /            \
             vnet-spoke1-cac      vnet-spoke2-cac
             10.61.0.0/16         10.62.0.0/16
             App workload 1       App workload 2

             No direct peering between Spoke 1 and Spoke 2.
```

## Predict before running

1. How many VNets? Three.
2. How many peering resources? Four. Each pair needs one in each direction.
3. Can Spoke 1 reach Spoke 2 through the hub? Not yet. Peering is non-transitive.
4. Any VMs, subnets, Firewall, Bastion, or VPN gateway? No.
5. Does `Connected` prove an app request worked? No. There are no workloads yet.

## What this phase creates

| Type | Count | Names |
|---|---:|---|
| Resource groups | 3 | rg-hubspoke-hub-cac, rg-hubspoke-spoke1-cac, rg-hubspoke-spoke2-cac |
| VNets | 3 | vnet-hub-cac (10.60/16), vnet-spoke1-cac (10.61/16), vnet-spoke2-cac (10.62/16) |
| Peerings | 4 | hub->spoke1, spoke1->hub, hub->spoke2, spoke2->hub |

## Run it

```powershell
Set-Location "C:\Users\shouk\Development\lab\azure-landing-zone-lab\terraform\envs\lab"
az login
az account show --query "{Name:name,Id:id,State:state}" --output table
$env:ARM_SUBSCRIPTION_ID = (az account show --query id --output tsv)

terraform init
terraform fmt -check
terraform validate
terraform plan -out=phase1.tfplan     # expect: 10 to add, 0 to change, 0 to destroy
terraform apply phase1.tfplan

Set-Location "C:\Users\shouk\Development\lab\azure-landing-zone-lab"
.\scripts\verify-peerings.ps1          # expect: 4 x Connected
```

If a peering shows `Initiated`, its reverse peering is missing or not ready yet.

State is local for now (`terraform/envs/lab/terraform.tfstate`, git-ignored). Phase 4 moves it to an Azure Storage backend.
Commit `.terraform.lock.hcl` after `terraform init`.

## Explain it in your own words

- Why is the hub a VNet, not automatically a router?
- Why two peering objects for one hub/spoke relationship?
- Why doesn't hub<->spoke1 plus hub<->spoke2 give spoke1<->spoke2?
- What does `Connected` actually prove?

If you can answer those four, Phase 1 worked.

## Cost

No VMs, Firewall, Bastion, VPN, or public IPs. Creating a peering is free; data crossing a peering is billed per GB. No traffic flows in this phase.

## Cleanup (only when the whole lab is done)

```powershell
Set-Location "C:\Users\shouk\Development\lab\azure-landing-zone-lab\terraform\envs\lab"
terraform plan -destroy
terraform destroy
```

## References

- https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-peering-overview
- https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering