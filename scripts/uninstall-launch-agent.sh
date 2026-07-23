#!/bin/zsh
set -euo pipefail

LABEL="com.codexusageloop.companion"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
USER_ID="$(id -u)"

if [[ -f "$PLIST_PATH" ]]; then
  launchctl bootout "gui/${USER_ID}" "$PLIST_PATH" >/dev/null 2>&1 || true
  rm "$PLIST_PATH"
  print "已移除登录 companion。"
else
  print "未找到登录 companion：$PLIST_PATH"
fi
