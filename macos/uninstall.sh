#!/usr/bin/env bash
set -euo pipefail

# macOS: 卸载开机自启 LaunchAgent 并清除所有已注入的代理环境变量

LABEL="com.user.veee-proxy-env"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
UID_NUM="$(id -u)"

launchctl bootout "gui/${UID_NUM}/${LABEL}" 2>/dev/null || true

if [[ -f "$PLIST_PATH" ]]; then
  rm -f "$PLIST_PATH"
  echo "[成功] 已删除 LaunchAgent: ${PLIST_PATH}"
else
  echo "[信息] 未发现 LaunchAgent 文件（已跳过）: ${PLIST_PATH}"
fi

for k in HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY http_proxy https_proxy all_proxy no_proxy; do
  launchctl unsetenv "$k" 2>/dev/null || true
done

echo "[成功] 已清空所有 launchctl 代理环境变量。重开 Antigravity 后即恢复直连。"
