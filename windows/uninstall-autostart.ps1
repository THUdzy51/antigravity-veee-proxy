<#
.SYNOPSIS
    Removes Enhanced Scheme A completely:
      1. Deletes the HKCU Run startup entry (AntigravityVeeeProxy).
      2. Calls uninstall.ps1 to clear User proxy environment variables and broadcast change.
#>

$ErrorActionPreference = "Stop"

$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$entryName = "AntigravityVeeeProxy"

if (Get-ItemProperty -Path $runKey -Name $entryName -ErrorAction SilentlyContinue) {
    Remove-ItemProperty -Path $runKey -Name $entryName
    Write-Host "[OK] Removed startup entry: HKCU Run\$entryName"
} else {
    Write-Host "[INFO] Startup entry not present: HKCU Run\$entryName"
}

$baseUninstall = Join-Path $PSScriptRoot "uninstall.ps1"
if (Test-Path -LiteralPath $baseUninstall) {
    & $baseUninstall
}
