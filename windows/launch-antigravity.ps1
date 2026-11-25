<#
.SYNOPSIS
    Windows 方案 B: 单应用隔离启动器。不修改全局环境变量，仅对本次启动的 Antigravity 注入代理并禁用 QUIC。

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\windows\launch-antigravity.ps1
    powershell -ExecutionPolicy Bypass -File .\windows\launch-antigravity.ps1 -Proxy "http://127.0.0.1:15236"
#>

param(
    [string]$Proxy = "",
    [string]$NoProxy = "localhost,127.0.0.1,::1",
    [string]$ExePath = ""
)

$ErrorActionPreference = "Stop"

function Resolve-SystemHttpProxy {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    $props = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
    if (-not $props -or $props.ProxyEnable -ne 1 -or [string]::IsNullOrWhiteSpace($props.ProxyServer)) {
        return $null
    }
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
    if (-not $target) { return $null }
    if ($target -notmatch "^https?://") { $target = "http://$target" }
    return $target
}

function Find-AntigravityExe {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Antigravity\Antigravity.exe"),
        (Join-Path $env:LOCALAPPDATA "Antigravity\Antigravity.exe"),
        (Join-Path $env:ProgramFiles "Antigravity\Antigravity.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Antigravity\Antigravity.exe")
    )
    foreach ($p in $candidates) {
        if ($p -and (Test-Path -LiteralPath $p)) {
            return $p
        }
    }
    return $null
}

if ([string]::IsNullOrWhiteSpace($Proxy)) {
    $Proxy = Resolve-SystemHttpProxy
    if (-not $Proxy) {
        $Proxy = "http://127.0.0.1:15236"
        Write-Host "[提示] 未检测到 Windows 系统代理，回退使用默认地址: $Proxy"
    } else {
        Write-Host "[信息] 已从 Windows 系统代理自动读取: $Proxy"
    }
}

if ([string]::IsNullOrWhiteSpace($ExePath)) {
    $ExePath = Find-AntigravityExe
}
if ([string]::IsNullOrWhiteSpace($ExePath) -or -not (Test-Path -LiteralPath $ExePath)) {
    throw "未自动找到 Antigravity.exe，请通过 -ExePath 参数手动指定安装路径。"
}

# 仅在当前进程作用域注入环境变量，不污染系统/用户全局环境
$env:HTTP_PROXY  = $Proxy
$env:HTTPS_PROXY = $Proxy
$env:ALL_PROXY   = $Proxy
$env:NO_PROXY    = $NoProxy
$env:http_proxy  = $Proxy
$env:https_proxy = $Proxy
$env:all_proxy   = $Proxy
$env:no_proxy    = $NoProxy

$bypassList = $NoProxy -replace ",", ";"
$argsList = @(
    "--proxy-server=$Proxy",
    "--proxy-bypass-list=$bypassList",
    "--disable-quic"
)

Write-Host "[信息] 正在启动 Antigravity ($ExePath)"
Write-Host "[信息] 本次代理: $Proxy（已禁用 QUIC）"
Start-Process -FilePath $ExePath -ArgumentList $argsList
