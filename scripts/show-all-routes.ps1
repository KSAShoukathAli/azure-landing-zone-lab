# show-all-routes.ps1
# Effective routes on all three probe NICs, filtered to the rows that matter.
$nics = @(
  @{ RG = "rg-hubspoke-hub-cac";    NIC = "nic-probe-hub-cac" },
  @{ RG = "rg-hubspoke-spoke1-cac"; NIC = "nic-probe-spoke1-cac" },
  @{ RG = "rg-hubspoke-spoke2-cac"; NIC = "nic-probe-spoke2-cac" }
)
foreach ($n in $nics) {
  Write-Host "`nEffective routes: $($n.NIC)" -ForegroundColor Cyan
  az network nic show-effective-route-table -g $n.RG -n $n.NIC `
    --query "value[?nextHopType!='None' || addressPrefix[0]=='10.0.0.0/8'].{Prefix:addressPrefix[0],NextHop:nextHopType}" `
    -o table
}
