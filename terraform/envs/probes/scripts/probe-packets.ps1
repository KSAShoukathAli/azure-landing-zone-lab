# probe-packets.ps1
# Optional. Asks the Spoke 1 guest to ping Hub and Spoke 2 via Azure Run Command.
# A Run Command failure is a VM management-plane issue, NOT proof of broken peering.
$ErrorActionPreference = 'Stop'
$rg = 'rg-hubspoke-spoke1-cac'
$vm = 'vm-probe-spoke1-cac'

function Probe([string]$label, [string]$ip) {
  Write-Host "`nSpoke 1 -> $label ($ip)" -ForegroundColor Cyan
  $script = "echo 'Checking guest route:'; ip route get $ip; echo 'Sending three ICMP requests:'; ping -n -c 3 -W 2 $ip; exit 0"
  az vm run-command invoke --resource-group $rg --name $vm --command-id RunShellScript --scripts $script --query 'value[].message' --output tsv
  if ($LASTEXITCODE -ne 0) {
    Write-Warning 'Run Command failed or timed out. Check VM Agent and outbound HTTPS 443; this is separate from VNet routing.'
  }
}

Probe 'Hub' '10.60.1.4'
Probe 'Spoke 2' '10.62.1.4'
Write-Host "`nIf Run Command cannot return results, rely on verify-routes.ps1." -ForegroundColor Yellow