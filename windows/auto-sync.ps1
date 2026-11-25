<#
.SYNOPSIS
    Enhanced Scheme A auto-sync script for Windows (Antigravity + Veee).
    Runs silently at logon:
      1. Detects Veee's actual local HTTP proxy port if Veee is connected
         (ignoring non-Veee proxies like Clash Verge).
      2. Falls back to Veee's verified default port (http://127.0.0.1:15236).
      3. Ensures User-level HTTP_PROXY / HTTPS_PROXY / ALL_PROXY / NO_PROXY
         are set and broadcasts WM_SETTINGCHANGE.
#>

param(
    [string]$DefaultProxy = "http://127.0.0.1:15236",
    [string]$NoProxy = "localhost,127.0.0.1,::1",
    [switch]$ForceBroadcast
)

$ErrorActionPreference = "Stop"

function Resolve-VeeeHttpProxy {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    $props = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
    if ($props -and $props.ProxyEnable -eq 1 -and -not [string]::IsNullOrWhiteSpace($props.ProxyServer)) {
        $server = $props.ProxyServer.Trim()
        $target = $null
        if ($server -match "=") {
            foreach ($part in ($server -split ";")) {
                if ($part -match "^https=(.+)$") { $target = $Matches[1]; break }
            }
            if (-not $target) {
                foreach ($part in ($server -split ";")) {
                    if ($part -match "^http=(.+)$") { $target = $Matches[1]; break }
                }
            }
        } else {
            $target = $server
        }

        if ($target) {
            $clean = $target -replace "^https?://", ""
            if ($clean -match "^(?:127\.0\.0\.1|localhost):(\d+)$") {
                $port = [int]$Matches[1]
                $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($conn) {
                    $proc = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
                    if ($proc -and $proc.ProcessName -match "Veee") {
                        return "http://127.0.0.1:$port"
                    }
                }
            }
        }
    }

    # If system proxy is not set by Veee yet, check if Veee core is already listening on default port 15236
    $veeePids = (Get-Process -Name "Veee" -ErrorAction SilentlyContinue).Id
    if ($veeePids) {
        $veeeConn = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
            Where-Object { $veeePids -contains $_.OwningProcess -and $_.LocalAddress -eq "127.0.0.1" -and $_.LocalPort -eq 15236 } |
            Select-Object -First 1
        if ($veeeConn) {
            return "http://127.0.0.1:15236"
        }
    }

    return $null
}

function Broadcast-EnvironmentChange {
    try {
        Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @"
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(
    IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
    uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
"@ -ErrorAction SilentlyContinue
        $HWND_BROADCAST = [IntPtr]0xffff
        $WM_SETTINGCHANGE = 0x1a
        $result = [UIntPtr]::Zero
        [Win32.NativeMethods]::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE, [UIntPtr]::Zero, "Environment", 2, 5000, [ref]$result) | Out-Null
    } catch {
        # Broadcast failure does not prevent persisted env vars from taking effect
    }
}

$detected = Resolve-VeeeHttpProxy
if ($detected) {
    $proxy = $detected
    $source = "detected-veee"
} else {
    $proxy = $DefaultProxy
    $source = "default-veee"
}

if ($proxy -notmatch "^https?://[A-Za-z0-9._:-]+$") {
    throw "Invalid proxy URL: $proxy"
}

$changed = $false
foreach ($k in @("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY")) {
    $cur = [Environment]::GetEnvironmentVariable($k, "User")
    if ($cur -ne $proxy) {
        [Environment]::SetEnvironmentVariable($k, $proxy, "User")
        $changed = $true
    }
}
if ([Environment]::GetEnvironmentVariable("NO_PROXY", "User") -ne $NoProxy) {
    [Environment]::SetEnvironmentVariable("NO_PROXY", $NoProxy, "User")
    $changed = $true
}

if ($changed -or $ForceBroadcast) {
    Broadcast-EnvironmentChange
}

$logPath = Join-Path $PSScriptRoot "sync.log"
$timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$line = "[$timestamp] proxy=$proxy source=$source changed=$changed"
$existing = @()
if (Test-Path -LiteralPath $logPath) {
    $existing = @(Get-Content -LiteralPath $logPath -ErrorAction SilentlyContinue | Select-Object -Last 19)
}
($existing + $line) | Set-Content -LiteralPath $logPath -Encoding UTF8

Write-Host "[OK] Antigravity Veee proxy synced: $proxy ($source, changed=$changed)"
