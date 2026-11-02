# verify-peerings.ps1
# Read-only Azure CLI check of the four hub-and-spoke peerings. Run after terraform apply.
$checks = @(
    @{ RG = "rg-hubspoke-hub-cac";    VNet = "vnet-hub-cac" },
    @{ RG = "rg-hubspoke-spoke1-cac"; VNet = "vnet-spoke1-cac" },
    @{ RG = "rg-hubspoke-spoke2-cac"; VNet = "vnet-spoke2-cac" }
)

foreach ($check in $checks) {
    Write-Host "`nPeering state for $($check.VNet)" -ForegroundColor Cyan
    az network vnet peering list `
      --resource-group $check.RG `
      --vnet-name $check.VNet `
      --query "[].{Peering:name,State:peeringState,Sync:peeringSyncLevel}" `
      --output table
}

Write-Host "`nExpected: 2 Connected rows for HUB, 1 for each SPOKE (4 total), all FullyInSync." -ForegroundColor Green
Write-Host "Note: this verifies control-plane peering state, not actual packet delivery."