<#
.SYNOPSIS
    只读检测 Windows 当前系统代理（Veee 等）的本地端口并测试连通性。
#>

param(
    [string]$TestUrl = "https://www.google.com/generate_204"
)

$ErrorActionPreference = "Stop"

function Get-WindowsSystemHttpProxy {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    $props = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
    if (-not $props) { return $null }

    $enabled = $props.ProxyEnable
    $server  = $props.ProxyServer
    $pac     = $props.AutoConfigURL

    Write-Host "=== 1. Windows 系统代理状态 ==="
    Write-Host "  ProxyEnable   = $enabled"
    Write-Host "  ProxyServer   = $server"
    if ($pac) { Write-Host "  AutoConfigURL = $pac" }

    if ($enabled -ne 1 -or [string]::IsNullOrWhiteSpace($server)) {
        return $null
    }

    # 兼容两种注册表格式:
    # 1) "127.0.0.1:15236"
    # 2) "http=127.0.0.1:15236;https=127.0.0.1:15236;socks=127.0.0.1:15235"
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
        $target = $server.Trim()
    }

    if (-not $target) { return $null }
    if ($target -notmatch "^https?://") {
        $target = "http://$target"
    }
    return $target
}

$proxyUrl = Get-WindowsSystemHttpProxy

Write-Host ""
Write-Host "=== 2. 当前用户级代理环境变量 ==="
foreach ($name in @("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY")) {
    $val = [Environment]::GetEnvironmentVariable($name, "User")
    Write-Host ("  {0,-12} = {1}" -f $name, $val)
}

Write-Host ""
Write-Host "=== 3. 探测结果与连通性测试 ==="
if (-not $proxyUrl) {
    Write-Host "[提示] 当前未开启 Windows 系统代理，请先打开并连接 Veee 后再运行此脚本。"
    exit 0
}

Write-Host "检测到本地 HTTP 代理: $proxyUrl"

$curlCmd = Get-Command "curl.exe" -ErrorAction SilentlyContinue
if ($curlCmd) {
    Write-Host "正在测试连通性: $TestUrl ..."
    & curl.exe -fsSIL --max-time 6 -x $proxyUrl $TestUrl | Select-Object -First 3
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] 代理 $proxyUrl 可正常连通。"
    } else {
        Write-Host "[WARN] 代理 $proxyUrl 测试失败，请检查 Veee 连接状态。"
    }
} else {
    Write-Host "[提示] 未找到 curl.exe，跳过连通性测试。"
}
