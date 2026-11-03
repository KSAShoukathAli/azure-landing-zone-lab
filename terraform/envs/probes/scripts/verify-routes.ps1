# verify-routes.ps1
# Read-only: compare two destinations from the VM in Spoke 1.
# Needs the VM running and Network Watcher enabled in Canada Central.
$ErrorActionPreference = 'Stop'
$rg  = 'rg-hubspoke-spoke1-cac'
$vm  = 'vm-probe-spoke1-cac'
$nic = 'nic-probe-spoke1-cac'
$src = '10.61.1.4'

Write-Host "`n1. Effective routes on $nic" -ForegroundColor Cyan
az network nic show-effective-route-table --resource-group $rg --name $nic `
  --query "value[].{Source:source,State:state,Prefix:join(', ',addressPrefix),NextHopType:nextHopType,NextHopIP:join(', ',nextHopIpAddress)}" `
  --output table
if ($LASTEXITCODE -ne 0) { throw 'Effective route lookup failed. Check that the VM is running.' }

$destinations = @(
  @{Name='Hub VM (direct peer)'; Ip='10.60.1.4'},
  @{Name='Spoke 2 VM (not directly peered)'; Ip='10.62.1.4'}
)
foreach ($d in $destinations) {
  Write-Host "`n2. Azure next hop: $src -> $($d.Ip) ($($d.Name))" -ForegroundColor Cyan
  az network watcher show-next-hop --resource-group $rg --vm $vm --nic $nic --source-ip $src --dest-ip $d.Ip --output table
  if ($LASTEXITCODE -ne 0) {
    Write-Warning 'Next-hop query failed. Network Watcher must be enabled for Canada Central; check permissions and VM status.'
  }
}
Write-Host "`nExpected: hub via VNetPeering; Spoke 2 matches 10.0.0.0/8 with next hop None (dropped)." -ForegroundColor Yellow
Write-Host 'These are Azure routing decisions, not proof that ICMP packets were delivered.'