#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}/.."
cd "$ROOT"
swift build -c release

APP="${ROOT}/dist/CodexUsageLoop.app"
LEGACY_APP="${ROOT}/dist/Codex Pet Usage.app"
rm -rf "$LEGACY_APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/CodexPetUsageMac" "$APP/Contents/MacOS/CodexUsageLoop"
chmod +x "$APP/Contents/MacOS/CodexUsageLoop"

ICONSET="${ROOT}/.build/AppIcon.iconset"
ICON_SOURCE="${ROOT}/Resources/AppIcon.png"
if [[ -f "$ICON_SOURCE" ]]; then
  cp "$ICON_SOURCE" "$APP/Contents/Resources/AppIcon.png"
  rm -rf "$ICONSET"
  mkdir -p "$ICONSET"
  ICON_TOOL="$(command -v magick || command -v convert || true)"
  if [[ -n "$ICON_TOOL" ]]; then
    "$ICON_TOOL" -background none "$ICON_SOURCE" -resize 16x16 "$ICONSET/icon_16x16.png"
    "$ICON_TOOL" -background none "$ICON_SOURCE" -resize 32x32 "$ICONSET/icon_16x16@2x.png"
    "$ICON_TOOL" -background none "$ICON_SOURCE" -resize 32x32 "$ICONSET/icon_32x32.png"
    "$ICON_TOOL" -background none "$ICON_SOURCE" -resize 64x64 "$ICONSET/icon_32x32@2x.png"
    "$ICON_TOOL" -background none "$ICON_SOURCE" -resize 128x128 "$ICONSET/icon_128x128.png"
    "$ICON_TOOL" -background none "$ICON_SOURCE" -resize 256x256 "$ICONSET/icon_128x128@2x.png"
    "$ICON_TOOL" -background none "$ICON_SOURCE" -resize 256x256 "$ICONSET/icon_256x256.png"
    "$ICON_TOOL" -background none "$ICON_SOURCE" -resize 512x512 "$ICONSET/icon_256x256@2x.png"
    "$ICON_TOOL" -background none "$ICON_SOURCE" -resize 512x512 "$ICONSET/icon_512x512.png"
    "$ICON_TOOL" -background none "$ICON_SOURCE" -resize 1024x1024 "$ICONSET/icon_512x512@2x.png"
    iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
  fi
fi

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDisplayName</key><string>CodexUsageLoop</string>
<key>CFBundleExecutable</key><string>CodexUsageLoop</string>
<key>CFBundleIdentifier</key><string>com.codexusageloop.mac</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleIconName</key><string>AppIcon</string>
<key>CFBundleName</key><string>CodexUsageLoop</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST

codesign --force --deep --sign - "$APP" >/dev/null

echo "Built: $APP"
