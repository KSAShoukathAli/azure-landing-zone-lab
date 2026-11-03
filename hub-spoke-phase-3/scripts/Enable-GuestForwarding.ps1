# Uses Azure CLI's documented @file syntax to preserve Linux script quoting and newlines.
# Does not alter Terraform or Azure resources outside the hub VM's guest OS.
$ErrorActionPreference = 'Stop'
$scriptFile = Join-Path $PSScriptRoot 'enable-hub-forwarding.sh'
if (-not (Test-Path -LiteralPath $scriptFile)) { throw "Missing Linux forwarding script: $scriptFile" }
Write-Host 'Enabling Linux forwarding on the existing hub VM using a script FILE...' -ForegroundColor Cyan
$output = & az vm run-command invoke `
  --resource-group rg-hubspoke-hub-cac `
  --name vm-probe-hub-cac `
  --command-id RunShellScript `
  --scripts "@$scriptFile" `
  --query 'value[].message' -o tsv
$exitCode = $LASTEXITCODE
$output | Out-Host
if ($exitCode -ne 0) { throw 'Azure Run Command failed. Check VM agent connectivity and command output.' }
if (($output -join "`n") -notmatch 'Kernel ip_forward:\s*1') {
  throw 'Azure command returned, but the Linux forwarding status was not confirmed as 1. Inspect stdout/stderr before proceeding.'
}
Write-Host 'Linux guest kernel forwarding confirmed: ip_forward = 1' -ForegroundColor Green
