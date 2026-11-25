#!/usr/bin/env bash
set -euo pipefail

# macOS: 为图形化应用（Antigravity 等）注入本地代理环境变量，并配置开机自动生效的 LaunchAgent
# 用法:
#   bash macos/install.sh                                  # 自动探测系统代理（失败则回退到默认 127.0.0.1:15236）
#   bash macos/install.sh --proxy http://127.0.0.1:15236   # 手动指定本地 HTTP 代理地址
#   bash macos/install.sh --dry-run                        # 仅预览配置，不实际写入

LABEL="com.user.veee-proxy-env"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
DEFAULT_PROXY="http://127.0.0.1:15236"
NO_PROXY_VAL="localhost,127.0.0.1,::1"
PROXY_URL=""
DRY_RUN="false"

usage() {
  cat <<'EOF'
用法: bash macos/install.sh [选项]

选项:
  --proxy <URL>        手动指定本地 HTTP 代理地址（默认自动探测系统代理，未开启时回退 http://127.0.0.1:15236）
  --no-proxy <LIST>    指定不走代理的地址列表（默认: localhost,127.0.0.1,::1）
  --dry-run            仅打印将要执行的配置，不修改系统
  -h, --help           显示此帮助
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --proxy)
      [[ $# -ge 2 ]] || { echo "[错误] --proxy 缺少参数" >&2; exit 1; }
      PROXY_URL="$2"; shift 2 ;;
    --proxy=*)
      PROXY_URL="${1#*=}"; shift ;;
    --no-proxy)
      [[ $# -ge 2 ]] || { echo "[错误] --no-proxy 缺少参数" >&2; exit 1; }
      NO_PROXY_VAL="$2"; shift 2 ;;
    --no-proxy=*)
      NO_PROXY_VAL="${1#*=}"; shift ;;
    --dry-run)
      DRY_RUN="true"; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "[错误] 未知参数: $1" >&2; usage >&2; exit 1 ;;
  esac
done

[[ "$(uname -s)" == "Darwin" ]] || { echo "[错误] 此脚本仅适用于 macOS，Windows 请使用 windows/install.ps1。" >&2; exit 1; }

detect_system_proxy() {
  local out enable host port
  out="$(scutil --proxy 2>/dev/null || true)"
  enable="$(echo "$out" | awk '/HTTPSEnable/{print $3; exit}')"
  host="$(echo "$out" | awk '/HTTPSProxy/{print $3; exit}')"
  port="$(echo "$out" | awk '/HTTPSPort/{print $3; exit}')"
  if [[ "$enable" == "1" && -n "$host" && -n "$port" ]]; then
    echo "http://${host}:${port}"
    return 0
  fi
  enable="$(echo "$out" | awk '/HTTPEnable/{print $3; exit}')"
  host="$(echo "$out" | awk '/HTTPProxy/{print $3; exit}')"
  port="$(echo "$out" | awk '/HTTPPort/{print $3; exit}')"
  if [[ "$enable" == "1" && -n "$host" && -n "$port" ]]; then
    echo "http://${host}:${port}"
    return 0
  fi
  return 1
}

if [[ -z "$PROXY_URL" ]]; then
  if PROXY_URL="$(detect_system_proxy)"; then
    echo "[信息] 自动探测到当前系统 HTTP 代理: ${PROXY_URL}"
  else
    PROXY_URL="$DEFAULT_PROXY"
    echo "[提示] 未检测到已开启的系统代理，使用 Veee 默认本地端口: ${PROXY_URL}"
  fi
fi

# 基础格式校验，防止非法字符进入 plist
if [[ ! "$PROXY_URL" =~ ^https?://[A-Za-z0-9._:-]+$ ]]; then
  echo "[错误] 代理地址格式无效: ${PROXY_URL}（示例: http://127.0.0.1:15236）" >&2
  exit 1
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[dry-run] PROXY_URL  = ${PROXY_URL}"
  echo "[dry-run] NO_PROXY   = ${NO_PROXY_VAL}"
  echo "[dry-run] PLIST_PATH = ${PLIST_PATH}"
  exit 0
fi

mkdir -p "$(dirname "$PLIST_PATH")"

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/sh</string>
        <string>-c</string>
        <string>for k in HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy; do /bin/launchctl setenv "\$k" "${PROXY_URL}"; done; for k in NO_PROXY no_proxy; do /bin/launchctl setenv "\$k" "${NO_PROXY_VAL}"; done</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

plutil -lint "$PLIST_PATH" >/dev/null

UID_NUM="$(id -u)"
launchctl bootout "gui/${UID_NUM}/${LABEL}" 2>/dev/null || true
launchctl bootstrap "gui/${UID_NUM}" "$PLIST_PATH"
sleep 1

echo "[成功] 已安装并加载开机自启配置: ${PLIST_PATH}"
echo "=== 当前生效的 launchctl 环境变量 ==="
for k in HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY; do
  printf "  %-12s = %s\n" "$k" "$(launchctl getenv "$k" || true)"
done
echo ""
echo "下一步: 保持 Veee 已连接，按 Cmd+Q 完全退出并重新打开原版 Antigravity 即可生效。"
