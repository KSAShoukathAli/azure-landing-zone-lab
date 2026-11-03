# Each test is sent as a .sh file to avoid PowerShell->Azure CLI quote splitting.
# Uses Azure VM Run Command. A successful Azure operation is not the same as a successful ping.
$ErrorActionPreference = 'Stop'
$checks = @(
  @{RG='rg-hubspoke-spoke1-cac';VM='vm-probe-spoke1-cac';Dst='10.60.1.4';Label='Spoke1 to Hub (baseline)'},
  @{RG='rg-hubspoke-spoke1-cac';VM='vm-probe-spoke1-cac';Dst='10.62.1.4';Label='Spoke1 to Spoke2 via Hub NVA'},
  @{RG='rg-hubspoke-spoke2-cac';VM='vm-probe-spoke2-cac';Dst='10.61.1.4';Label='Spoke2 to Spoke1 via Hub NVA'}
)
foreach ($c in $checks) {
  Write-Host "`n$($c.Label)" -ForegroundColor Cyan
  $path = Join-Path ([System.IO.Path]::GetTempPath()) ("hubspoke-probe-" + $c.VM + ".sh")
  $lines = @(
    '#!/bin/sh',
    'echo "Guest route:"',
    "ip route get $($c.Dst)",
    'echo "PING:"',
    "ping -n -c 3 -W 2 $($c.Dst)",
    'result=$?',
    'echo "ping_exit=$result"'
  )
  [System.IO.File]::WriteAllText($path, (($lines -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
  try {
    $output = & az vm run-command invoke `
      --resource-group $c.RG `
      --name $c.VM `
      --command-id RunShellScript `
      --scripts "@$path" `
      --query 'value[].message' -o tsv
    $exitCode = $LASTEXITCODE
    $output | Out-Host
    if ($exitCode -ne 0) {
      Write-Warning 'Run Command failed. Cannot infer packet-delivery results.'
    } elseif (($output -join "`n") -match 'ping_exit=0') {
      Write-Host 'Packet test: SUCCESS (ping_exit=0)' -ForegroundColor Green
    } elseif (($output -join "`n") -match 'ping_exit=[1-9]') {
      Write-Warning 'Packet test: FAILED (ping returned nonzero). Inspect routing and forwarding.'
    } else {
      Write-Warning 'No clear ping_exit marker. Do not assume the packet test succeeded.'
    }
  }
  finally { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
}
