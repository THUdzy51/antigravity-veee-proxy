#!/usr/bin/env bash
set -euo pipefail

# 自动检测 macOS 当前系统代理配置并验证连通性（只读，不修改任何设置）

TEST_URL="${TEST_URL:-https://www.google.com/generate_204}"

echo "=== 1. macOS 系统代理状态 (scutil --proxy) ==="
PROXY_OUT="$(scutil --proxy)"
echo "$PROXY_OUT" | grep -E "HTTPEnable|HTTPProxy|HTTPPort|HTTPSEnable|HTTPSProxy|HTTPSPort|SOCKSEnable|SOCKSProxy|SOCKSPort|ProxyAutoConfigEnable" || true

HTTP_ENABLE="$(echo "$PROXY_OUT" | awk '/HTTPEnable/{print $3; exit}')"
HTTP_HOST="$(echo "$PROXY_OUT" | awk '/HTTPProxy/{print $3; exit}')"
HTTP_PORT="$(echo "$PROXY_OUT" | awk '/HTTPPort/{print $3; exit}')"

HTTPS_ENABLE="$(echo "$PROXY_OUT" | awk '/HTTPSEnable/{print $3; exit}')"
HTTPS_HOST="$(echo "$PROXY_OUT" | awk '/HTTPSProxy/{print $3; exit}')"
HTTPS_PORT="$(echo "$PROXY_OUT" | awk '/HTTPSPort/{print $3; exit}')"

SOCKS_ENABLE="$(echo "$PROXY_OUT" | awk '/SOCKSEnable/{print $3; exit}')"
SOCKS_HOST="$(echo "$PROXY_OUT" | awk '/SOCKSProxy/{print $3; exit}')"
SOCKS_PORT="$(echo "$PROXY_OUT" | awk '/SOCKSPort/{print $3; exit}')"

DETECTED_HTTP=""
if [[ "$HTTPS_ENABLE" == "1" && -n "$HTTPS_HOST" && -n "$HTTPS_PORT" ]]; then
  DETECTED_HTTP="http://${HTTPS_HOST}:${HTTPS_PORT}"
elif [[ "$HTTP_ENABLE" == "1" && -n "$HTTP_HOST" && -n "$HTTP_PORT" ]]; then
  DETECTED_HTTP="http://${HTTP_HOST}:${HTTP_PORT}"
fi

echo ""
echo "=== 2. 探测结果 ==="
if [[ -n "$DETECTED_HTTP" ]]; then
  echo "HTTP/HTTPS 代理: ${DETECTED_HTTP}"
else
  echo "HTTP/HTTPS 代理: 未开启（请先打开并连接 Veee）"
fi

if [[ "$SOCKS_ENABLE" == "1" && -n "$SOCKS_HOST" && -n "$SOCKS_PORT" ]]; then
  echo "SOCKS5 代理    : socks5h://${SOCKS_HOST}:${SOCKS_PORT}"
fi

echo ""
echo "=== 3. 当前 launchctl GUI 环境变量 ==="
for k in HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY; do
  printf "  %-12s = %s\n" "$k" "$(launchctl getenv "$k" || true)"
done

if [[ -n "$DETECTED_HTTP" ]]; then
  echo ""
  echo "=== 4. 连通性测试 (${TEST_URL}) ==="
  if curl -fsSIL --max-time 6 -x "$DETECTED_HTTP" "$TEST_URL" | head -n 1; then
    echo "[OK] 代理 ${DETECTED_HTTP} 可正常连通。"
  else
    echo "[WARN] 代理 ${DETECTED_HTTP} 测试超时或失败，请确认 Veee 已正常连接。"
  fi
fi
