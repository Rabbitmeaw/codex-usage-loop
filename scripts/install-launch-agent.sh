#!/bin/zsh
set -euo pipefail

if [[ $# -gt 1 ]]; then
  print -u2 "用法：zsh scripts/install-launch-agent.sh [CodexUsageLoop.app 的路径]"
  exit 64
fi

ROOT="${0:A:h}/.."
APP_PATH="${1:-${ROOT}/dist/CodexUsageLoop.app}"
APP_PATH="${APP_PATH:A}"
LABEL="com.codexusageloop.companion"
AGENTS_DIR="${HOME}/Library/LaunchAgents"
PLIST_PATH="${AGENTS_DIR}/${LABEL}.plist"
USER_ID="$(id -u)"

if [[ ! -d "$APP_PATH" || ! -x "$APP_PATH/Contents/MacOS/CodexUsageLoop" ]]; then
  print -u2 "未找到可运行的 CodexUsageLoop.app：$APP_PATH"
  print -u2 "请先运行 zsh scripts/build-app.sh，或传入已安装应用的绝对路径。"
  exit 66
fi

mkdir -p "$AGENTS_DIR"
cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>${LABEL}</string>
<key>ProgramArguments</key><array>
  <string>/usr/bin/open</string>
  <string>-gj</string>
  <string>${APP_PATH}</string>
</array>
<key>RunAtLoad</key><true/>
</dict></plist>
PLIST

launchctl bootout "gui/${USER_ID}" "$PLIST_PATH" >/dev/null 2>&1 || true
launchctl bootstrap "gui/${USER_ID}" "$PLIST_PATH"

print "已安装登录 companion：$PLIST_PATH"
print "它只在 Codex/ChatGPT Desktop 运行期间启用用量读取和宠物定位；退出 Codex 后会停止这些定时任务。"
