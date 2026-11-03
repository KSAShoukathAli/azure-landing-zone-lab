param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][ValidateRange(0,2)][int]$Stage
)
$ErrorActionPreference = 'Stop'

$labMain = Join-Path $RepoRoot 'terraform/envs/lab/main.tf'
$probesDir = Join-Path $RepoRoot 'terraform/envs/probes'
$probesMain = Join-Path $probesDir 'main.tf'
if (-not (Test-Path (Join-Path $probesDir 'phase3.routes.tf')) -or
    -not (Test-Path $probesMain) -or -not (Test-Path $labMain)) {
    throw 'Install Phase 3 first, and run from the correct repository root.'
}
$enable1 = if ($Stage -ge 1) { 'true' } else { 'false' }
$enable2 = if ($Stage -ge 2) { 'true' } else { 'false' }
@"
phase3_enable_spoke1_route    = $enable1
phase3_enable_spoke2_route    = $enable2
phase3_enable_hub_forwarding = $enable2
"@ | Set-Content -LiteralPath (Join-Path $probesDir 'phase3.auto.tfvars') -Encoding ASCII

# Only receiving SPOKES need to accept forwarded traffic from the hub NVA.
$content = Get-Content -LiteralPath $labMain -Raw
foreach ($peering in @('spoke1_to_hub', 'spoke2_to_hub')) {
    $pattern = '(?s)(resource\s+"azurerm_virtual_network_peering"\s+"' + $peering + '"\s*\{.*?\ballow_forwarded_traffic\s*=\s*)(true|false)'
    $hits = [regex]::Matches($content, $pattern)
    if ($hits.Count -ne 1) { throw "Unexpected peering layout for $peering; no safe patch possible." }
    $content = [regex]::Replace($content, $pattern, '${1}' + $enable2)
}
[System.IO.File]::WriteAllText($labMain, $content, (New-Object System.Text.UTF8Encoding($false)))

switch ($Stage) {
  0 { Write-Host 'Stage 0: remove UDRs and disable forwarding in Terraform. APPLY PROBES FIRST, then LAB.' -ForegroundColor Yellow }
  1 { Write-Host 'Stage 1: add one Spoke 1 UDR only. APPLY PROBES ONLY.' -ForegroundColor Cyan }
  2 { Write-Host 'Stage 2: add return UDR, hub NIC forwarding, and allow forwarded traffic. APPLY LAB FIRST, then PROBES. Guest OS setup is separate.' -ForegroundColor Cyan }
}
Write-Host 'No Azure changes have been applied yet. Review terraform plan in the indicated roots.'
