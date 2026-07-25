#!/bin/zsh
set -euo pipefail

if [[ $# -ne 1 ]]; then
  print -u2 "用法：zsh scripts/validate-release-ref.sh <vX.Y.Z>"
  exit 64
fi

TAG="$1"
if [[ ! "$TAG" =~ '^v[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
  print -u2 "正式 Release tag 必须类似 v0.1.2"
  exit 64
fi

VERSION="${TAG#v}"
ROOT="${0:A:h}/.."
cd "$ROOT"

assert_contains() {
  local file_path="$1"
  local expected="$2"
  if ! grep -Fq "$expected" "$file_path"; then
    print -u2 "${file_path} 的版本与 tag ${TAG} 不一致：缺少 ${expected}"
    exit 1
  fi
}

assert_contains "scripts/build-app.sh" \
  "<key>CFBundleShortVersionString</key><string>${VERSION}</string>"
assert_contains "Sources/CodexPetUsageMac/CodexAppServerClient.swift" \
  "\"version\": \"${VERSION}\""
assert_contains "src/CodexUsageLoop.Windows/CodexUsageLoop.Windows.csproj" \
  "<Version>${VERSION}</Version>"
assert_contains "src/CodexUsageLoop.Windows/CodexAppServerClient.cs" \
  "version = \"${VERSION}\""

NOTES="docs/releases/${TAG}.md"
if [[ ! -s "$NOTES" ]]; then
  print -u2 "缺少非空的版本化 Release 说明：${NOTES}"
  exit 1
fi

for required in "## 验证" "Codex CLI" "ad-hoc" "未公证" "Authenticode" "SHA-256"; do
  assert_contains "$NOTES" "$required"
done

print "Release ref validated: ${TAG}"
