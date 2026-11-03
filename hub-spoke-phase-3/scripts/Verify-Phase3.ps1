# Read-only Azure routing and peering evidence. Does not test packet delivery.
$ErrorActionPreference = 'Stop'
$targets = @(
  @{RG='rg-hubspoke-spoke1-cac'; NIC='nic-probe-spoke1-cac'; VM='vm-probe-spoke1-cac'; Src='10.61.1.4'; Dst='10.62.1.4'},
  @{RG='rg-hubspoke-spoke2-cac'; NIC='nic-probe-spoke2-cac'; VM='vm-probe-spoke2-cac'; Src='10.62.1.4'; Dst='10.61.1.4'}
)
foreach ($t in $targets) {
  Write-Host "`nEffective routes on $($t.NIC)" -ForegroundColor Cyan
  az network nic show-effective-route-table -g $t.RG -n $t.NIC --query "value[?nextHopType=='VirtualAppliance' || nextHopType=='VNetPeering' || nextHopType=='VnetLocal'].{Prefix:addressPrefix[0],Hop:nextHopType,NextIP:nextHopIpAddress}" -o table
  if ($LASTEXITCODE -ne 0) { throw 'Effective route query failed. Inspect VM state and Azure role.' }
  Write-Host "Next hop: $($t.Src) -> $($t.Dst)" -ForegroundColor Cyan
  az network watcher show-next-hop --resource-group $t.RG --vm $t.VM --nic $t.NIC --source-ip $t.Src --dest-ip $t.Dst --query '{NextHop:nextHopType,NextIP:nextHopIpAddress,Route:routeTableId}' -o table
  if ($LASTEXITCODE -ne 0) { Write-Warning 'Next-hop query requires Network Watcher in Canada Central.' }
}
Write-Host "`nHub NIC Azure IP forwarding:" -ForegroundColor Cyan
az network nic show -g rg-hubspoke-hub-cac -n nic-probe-hub-cac --query '{Name:name,IPForwarding:enableIPForwarding}' -o table
Write-Host "`nReceiving-side peering forward settings:" -ForegroundColor Cyan
az network vnet peering show -g rg-hubspoke-spoke1-cac --vnet-name vnet-spoke1-cac -n peer-spoke1-to-hub --query '{Name:name,Forwarded:allowForwardedTraffic,State:peeringState}' -o table
az network vnet peering show -g rg-hubspoke-spoke2-cac --vnet-name vnet-spoke2-cac -n peer-spoke2-to-hub --query '{Name:name,Forwarded:allowForwardedTraffic,State:peeringState}' -o table
Write-Host "`nRemember: a VirtualAppliance next hop does not itself prove traffic was delivered." -ForegroundColor Yellow
