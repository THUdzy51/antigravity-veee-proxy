<#
.SYNOPSIS
    Installs Enhanced Scheme A:
      1. Runs auto-sync.ps1 immediately (writes User env vars + broadcasts WM_SETTINGCHANGE).
      2. Registers a silent logon entry under HKCU\Software\Microsoft\Windows\CurrentVersion\Run
         so it runs automatically on every boot without any console flash.
#>

param(
    [string]$DefaultProxy = "http://127.0.0.1:15236",
    [string]$NoProxy = "localhost,127.0.0.1,::1"
)

$ErrorActionPreference = "Stop"

$syncScript = Join-Path $PSScriptRoot "auto-sync.ps1"
$vbsLauncher = Join-Path $PSScriptRoot "run-hidden.vbs"

if (-not (Test-Path -LiteralPath $syncScript)) { throw "Missing: $syncScript" }
if (-not (Test-Path -LiteralPath $vbsLauncher)) { throw "Missing: $vbsLauncher" }

& $syncScript -DefaultProxy $DefaultProxy -NoProxy $NoProxy -ForceBroadcast

$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$entryName = "AntigravityVeeeProxy"
$entryValue = "wscript.exe `"$vbsLauncher`""
Set-ItemProperty -Path $runKey -Name $entryName -Value $entryValue

Write-Host ""
Write-Host "=== Verified User Environment Variables ==="
foreach ($k in @("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY")) {
    Write-Host ("  {0,-12} = {1}" -f $k, [Environment]::GetEnvironmentVariable($k, "User"))
}
Write-Host ""
Write-Host "=== Verified Startup Registration ==="
Write-Host ("  HKCU Run\{0} = {1}" -f $entryName, (Get-ItemPropertyValue -Path $runKey -Name $entryName))
