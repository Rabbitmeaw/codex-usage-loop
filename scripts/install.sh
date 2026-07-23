#!/bin/zsh
set -euo pipefail

INSTALL_LOGIN_AGENT=false
if [[ "${1:-}" == "--with-login-agent" ]]; then
  INSTALL_LOGIN_AGENT=true
  shift
fi

if [[ $# -gt 1 ]]; then
  print -u2 "用法：zsh scripts/install.sh [--with-login-agent] [安装目录]"
  exit 64
fi

ROOT="${0:A:h}/.."
if [[ $# -eq 1 ]]; then
  DESTINATION_DIR="$1"
elif [[ -w /Applications ]]; then
  DESTINATION_DIR="/Applications"
else
  DESTINATION_DIR="${HOME}/Applications"
fi
DESTINATION_DIR="${DESTINATION_DIR:A}"
APP_SOURCE="${ROOT}/dist/CodexUsageLoop.app"
APP_DESTINATION="${DESTINATION_DIR}/CodexUsageLoop.app"

# A local Apple Development identity keeps macOS privacy approvals tied to the
# same bundle and team across rebuilds. This is not Developer ID distribution
# signing and is intentionally optional for open-source users.
LOCAL_SIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
if [[ -z "$LOCAL_SIGN_IDENTITY" ]]; then
  LOCAL_SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F '"' '/Apple Development:/ { print $2; exit }')"
fi
if [[ -n "$LOCAL_SIGN_IDENTITY" ]]; then
  CODESIGN_IDENTITY="$LOCAL_SIGN_IDENTITY" zsh "${ROOT}/scripts/build-app.sh"
  print "本机安装使用稳定的 Apple Development 签名，以保留 macOS 隐私授权。"
else
  zsh "${ROOT}/scripts/build-app.sh"
  print "未发现本机 Apple Development 签名；将使用临时签名，macOS 隐私授权可能在更新后需要重新确认。"
fi
mkdir -p "$DESTINATION_DIR"
rm -rf "$APP_DESTINATION"
ditto "$APP_SOURCE" "$APP_DESTINATION"
if [[ "$INSTALL_LOGIN_AGENT" == true ]]; then
  zsh "${ROOT}/scripts/install-launch-agent.sh" "$APP_DESTINATION"
else
  print "未安装登录 companion；如需随 Codex 宠物自动待命，请执行："
  print "zsh scripts/install-launch-agent.sh \"$APP_DESTINATION\""
fi

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$APP_DESTINATION"
fi

print "已安装：$APP_DESTINATION"
print "已注册到 Launch Services；应用应显示在启动台和 ${DESTINATION_DIR}。"
