#!/bin/zsh
set -euo pipefail

ROOT="$(cd "${0:A:h}/.." && pwd)"
INSTALLED_APP="/Applications/CodexUsageLoop.app"
APP="${CODEX_USAGE_LOOP_APP:-$INSTALLED_APP}"
if [[ ! -x "$APP/Contents/MacOS/CodexUsageLoop" ]]; then
  APP="${ROOT}/dist/CodexUsageLoop.app"
fi
EXECUTABLE="${APP}/Contents/MacOS/CodexUsageLoop"
LOCK_DIRECTORY="/private/tmp/com.codexusageloop.restart.lock"
PROCESS_PATTERN="CodexUsageLoop.app/Contents/MacOS/CodexUsageLoop"

if ! mkdir "$LOCK_DIRECTORY" 2>/dev/null; then
  print -u2 "已有一次重启正在进行；为避免单实例竞态，请等待它完成。"
  exit 75
fi
trap 'rmdir "$LOCK_DIRECTORY"' EXIT INT TERM

if [[ ! -x "$EXECUTABLE" ]]; then
  print -u2 "未找到应用包，请先运行：zsh scripts/build-app.sh"
  exit 1
fi

typeset -a running_pids
running_pids=( ${(f)$(pgrep -f "$PROCESS_PATTERN" || true)} )
if (( ${#running_pids[@]} > 0 )); then
  kill -TERM "${running_pids[@]}"
fi

for _ in {1..30}; do
  if ! pgrep -f "$PROCESS_PATTERN" >/dev/null; then
    break
  fi
  sleep 0.1
done

running_pids=( ${(f)$(pgrep -f "$PROCESS_PATTERN" || true)} )
if (( ${#running_pids[@]} > 0 )); then
  kill -KILL "${running_pids[@]}"
  sleep 0.2
fi

if pgrep -f "$PROCESS_PATTERN" >/dev/null; then
  print -u2 "旧实例未能退出；为避免单实例竞态，未启动新实例。"
  exit 1
fi

for _ in {1..3}; do
  open -n "$APP"
  sleep 0.5
  new_pids=( ${(f)$(pgrep -f "$PROCESS_PATTERN" || true)} )
  if (( ${#new_pids[@]} == 1 )); then
    exit 0
  fi
done

print -u2 "新实例未能稳定启动；可能仍在等待 macOS 注销旧实例。"
exit 1
