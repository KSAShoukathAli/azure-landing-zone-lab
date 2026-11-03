param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference = 'Stop'

$pack = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$labMain = Join-Path $RepoRoot 'terraform/envs/lab/main.tf'
$probesDir = Join-Path $RepoRoot 'terraform/envs/probes'
$probesMain = Join-Path $probesDir 'main.tf'

foreach ($file in @($labMain, $probesMain)) {
    if (-not (Test-Path $file)) { throw "Expected existing Terraform file missing: $file" }
}

$labContent = Get-Content -LiteralPath $labMain -Raw
$probesContent = Get-Content -LiteralPath $probesMain -Raw
if ($labContent -notmatch 'resource "azurerm_virtual_network_peering" "spoke1_to_hub"' -or
    $labContent -notmatch 'resource "azurerm_virtual_network_peering" "spoke2_to_hub"') {
    throw 'Phase 1 Terraform does not match this lab. No changes made.'
}
$needle = 'resource "azurerm_network_interface" "probe" {'
if (-not $probesContent.Contains($needle)) {
    throw 'Phase 2 Terraform does not have the expected probe NIC resource. No changes made.'
}

$backup = Join-Path $pack '_backup'
New-Item -ItemType Directory -Force -Path $backup | Out-Null
$backupLab = Join-Path $backup 'phase1-main.tf.original'
$backupProbes = Join-Path $backup 'phase2-main.tf.original'
if (-not (Test-Path $backupLab)) { Copy-Item -LiteralPath $labMain -Destination $backupLab }
if (-not (Test-Path $backupProbes)) { Copy-Item -LiteralPath $probesMain -Destination $backupProbes }

if ($probesContent -notmatch '\bip_forwarding_enabled\s*=') {
    $replacement = $needle + "`r`n" + '  ip_forwarding_enabled = each.key == "hub" && var.phase3_enable_hub_forwarding'
    $probesContent = $probesContent.Replace($needle, $replacement)
    [System.IO.File]::WriteAllText($probesMain, $probesContent, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host 'Patched Phase 2 hub NIC with staged Terraform IP forwarding (default off).'
} elseif ($probesContent -notmatch 'ip_forwarding_enabled\s*=\s*each.key\s*==\s*"hub"\s*&&\s*var.phase3_enable_hub_forwarding') {
    throw 'Existing ip_forwarding_enabled setting differs from this lab. Inspect manually; not overwriting.'
}

foreach ($name in @('phase3.routes.tf', 'phase3.variables.tf')) {
    $src = Join-Path (Join-Path $pack 'terraform') $name
    $dest = Join-Path $probesDir $name
    if (Test-Path $dest) {
        if ((Get-FileHash $dest).Hash -ne (Get-FileHash $src).Hash) {
            throw "Existing $name differs from packaged file. Inspect before overwriting."
        }
    } else {
        Copy-Item $src $dest
    }
}

$vars = Join-Path $probesDir 'phase3.auto.tfvars'
if (-not (Test-Path $vars)) {
    @'
phase3_enable_spoke1_route    = false
phase3_enable_spoke2_route    = false
phase3_enable_hub_forwarding = false
'@ | Set-Content -LiteralPath $vars -Encoding ASCII
}
Write-Host 'Phase 3 installed. No Azure resources were changed.' -ForegroundColor Green
Write-Host 'Next: .\hub-spoke-phase-3\scripts\Set-Phase3Stage.ps1 -RepoRoot (Get-Location).Path -Stage 1'
