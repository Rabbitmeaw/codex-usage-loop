#!/bin/zsh
set -euo pipefail

if [[ $# -ne 1 ]]; then
  print -u2 "用法：zsh scripts/package-release.sh <version>"
  exit 64
fi

VERSION="$1"
if [[ ! "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z]+)*$' ]]; then
  print -u2 "版本号必须类似 0.1.0 或 0.1.0-rc.1"
  exit 64
fi

ROOT="${0:A:h}/.."
cd "$ROOT"
APP="dist/CodexUsageLoop.app"
ARCHIVE="dist/CodexUsageLoop-${VERSION}.zip"
CHECKSUMS="dist/SHA256SUMS.txt"
METADATA="dist/RELEASE_METADATA.txt"

zsh scripts/build-app.sh
codesign --verify --deep --strict "$APP"
rm -f "$ARCHIVE" "$CHECKSUMS" "$METADATA"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ARCHIVE"
(cd dist && shasum -a 256 "${ARCHIVE:t}" > "${CHECKSUMS:t}")

COMMIT="$(git rev-parse --verify HEAD 2>/dev/null || true)"
if [[ -z "$COMMIT" ]]; then
  COMMIT="uncommitted"
fi

{
  print "version=${VERSION}"
  print "built_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  print "commit=${COMMIT}"
  print "signed=ad-hoc"
  print "notarized=no"
} > "$METADATA"

print "Release artifacts:"
print "  $ARCHIVE"
print "  $CHECKSUMS"
print "  $METADATA"
