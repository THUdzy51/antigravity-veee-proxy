<#
.SYNOPSIS
    Windows: 一键清除由 install.ps1 写入的用户级代理环境变量并广播刷新。
#>

$ErrorActionPreference = "Stop"

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
        # 忽略广播异常
    }
}

foreach ($k in @("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY")) {
    [Environment]::SetEnvironmentVariable($k, $null, "User")
}
Broadcast-EnvironmentChange

Write-Host "[成功] 已清除用户级代理环境变量（HTTP_PROXY / HTTPS_PROXY / ALL_PROXY / NO_PROXY）。"
Write-Host "       完全退出并重开 Antigravity 后即恢复默认直连。"
