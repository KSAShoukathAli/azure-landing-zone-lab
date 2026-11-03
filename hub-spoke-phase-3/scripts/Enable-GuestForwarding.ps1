# Azure Run Command needs VM-agent connectivity. A failed invoke is not routing evidence.
$ErrorActionPreference = 'Stop'
$script = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'enable-hub-forwarding.sh') -Raw
Write-Host 'Enabling Linux kernel forwarding on the EXISTING hub VM via Azure Run Command...' -ForegroundColor Cyan
az vm run-command invoke --resource-group rg-hubspoke-hub-cac --name vm-probe-hub-cac --command-id RunShellScript --scripts $script --query 'value[].message' -o tsv
if ($LASTEXITCODE -ne 0) {
    Write-Warning 'Azure Run Command failed. Do not claim traffic forwarding is operational. Check VM Agent and management-plane outbound requirements; see README.'
    exit 1
}
Write-Host 'Review the command output for `Kernel ip_forward: 1` and errors.' -ForegroundColor Green
