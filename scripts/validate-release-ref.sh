#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  printf '%s\n' "用法：bash scripts/validate-release-ref.sh <vX.Y.Z>" >&2
  exit 64
fi

TAG="$1"
STABLE_TAG_PATTERN='^v[0-9]+\.[0-9]+\.[0-9]+$'
if [[ ! "$TAG" =~ $STABLE_TAG_PATTERN ]]; then
  printf '%s\n' "正式 Release tag 必须类似 v0.1.2" >&2
  exit 64
fi

VERSION="${TAG#v}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

assert_contains() {
  local file_path="$1"
  local expected="$2"
  if ! grep -Fq "$expected" "$file_path"; then
    printf '%s\n' "${file_path} 的版本与 tag ${TAG} 不一致：缺少 ${expected}" >&2
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
  printf '%s\n' "缺少非空的版本化 Release 说明：${NOTES}" >&2
  exit 1
fi

for required in "## 验证" "Codex CLI" "ad-hoc" "未公证" "Authenticode" "SHA-256"; do
  assert_contains "$NOTES" "$required"
done

printf '%s\n' "Release ref validated: ${TAG}"
