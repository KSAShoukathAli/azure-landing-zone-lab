# Optional actual data-plane ping. Requires working Azure VM Run Command service.
$ErrorActionPreference = 'Stop'
$checks = @(
 @{RG='rg-hubspoke-spoke1-cac';VM='vm-probe-spoke1-cac';Dst='10.60.1.4';Label='Spoke1 to Hub (baseline)'},
 @{RG='rg-hubspoke-spoke1-cac';VM='vm-probe-spoke1-cac';Dst='10.62.1.4';Label='Spoke1 to Spoke2 via Hub NVA'},
 @{RG='rg-hubspoke-spoke2-cac';VM='vm-probe-spoke2-cac';Dst='10.61.1.4';Label='Spoke2 to Spoke1 via Hub NVA'}
)
foreach ($c in $checks) {
  Write-Host "`n$($c.Label)" -ForegroundColor Cyan
  $cmd = 'echo "Guest route:"; ip route get ' + $c.Dst + '; echo "PING:"; ping -n -c 3 -W 2 ' + $c.Dst + '; echo "ping_exit=$?"'
  az vm run-command invoke --resource-group $c.RG --name $c.VM --command-id RunShellScript --scripts $cmd --query 'value[].message' -o tsv
  if ($LASTEXITCODE -ne 0) { Write-Warning 'VM management command failed: cannot infer packet-delivery results.' }
}
Write-Host "`nInspect ping statistics AND ping_exit output. Azure Run Command itself may report success even when ping fails." -ForegroundColor Yellow
