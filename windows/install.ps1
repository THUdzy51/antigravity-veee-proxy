<#
.SYNOPSIS
    Windows 方案 A: 将 Veee 本地 HTTP 代理写入用户级永久环境变量（开机自动生效，无需管理员权限）。

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\windows\install.ps1
    powershell -ExecutionPolicy Bypass -File .\windows\install.ps1 -Proxy "http://127.0.0.1:15236"
#>

param(
    [string]$Proxy = "",
    [string]$NoProxy = "localhost,127.0.0.1,::1",
    [switch]$DryRun
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
        # 广播失败不影响持久化生效
    }
}

if ([string]::IsNullOrWhiteSpace($Proxy)) {
    $detected = Resolve-SystemHttpProxy
    if ($detected) {
        $Proxy = $detected
        Write-Host "[信息] 自动探测到当前 Windows 系统代理: $Proxy"
    } else {
        $Proxy = "http://127.0.0.1:15236"
        Write-Host "[提示] 未检测到已开启的系统代理，使用默认本地端口: $Proxy"
        Write-Host "       如 Veee 在你的 Windows 上使用其他端口，请先连上 Veee 后重新运行，或传入 -Proxy 参数。"
    }
}

if ($Proxy -notmatch "^https?://[A-Za-z0-9._:-]+$") {
    throw "代理地址格式无效: $Proxy（示例: http://127.0.0.1:15236）"
}

if ($DryRun) {
    Write-Host "[dry-run] 将写入用户级环境变量:"
    Write-Host "  HTTP_PROXY / HTTPS_PROXY / ALL_PROXY = $Proxy"
    Write-Host "  NO_PROXY                             = $NoProxy"
    exit 0
}

foreach ($k in @("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY")) {
    [Environment]::SetEnvironmentVariable($k, $Proxy, "User")
}
[Environment]::SetEnvironmentVariable("NO_PROXY", $NoProxy, "User")
Broadcast-EnvironmentChange

Write-Host "[成功] 已写入用户级永久代理环境变量（开机自动生效）:"
foreach ($k in @("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY")) {
    Write-Host ("  {0,-12} = {1}" -f $k, [Environment]::GetEnvironmentVariable($k, "User"))
}
Write-Host ""
Write-Host "下一步: 保持 Veee 已连接，完全退出 Antigravity（含系统托盘）后，直接双击原版图标重新打开即可。"
