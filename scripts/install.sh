#!/bin/zsh
set -euo pipefail

if [[ $# -gt 1 ]]; then
  print -u2 "用法：zsh scripts/install.sh [安装目录]"
  exit 64
fi

ROOT="${0:A:h}/.."
DESTINATION_DIR="${1:-${HOME}/Applications}"
DESTINATION_DIR="${DESTINATION_DIR:A}"
APP_SOURCE="${ROOT}/dist/CodexUsageLoop.app"
APP_DESTINATION="${DESTINATION_DIR}/CodexUsageLoop.app"

zsh "${ROOT}/scripts/build-app.sh"
mkdir -p "$DESTINATION_DIR"
rm -rf "$APP_DESTINATION"
ditto "$APP_SOURCE" "$APP_DESTINATION"
zsh "${ROOT}/scripts/install-launch-agent.sh" "$APP_DESTINATION"

print "已安装：$APP_DESTINATION"
