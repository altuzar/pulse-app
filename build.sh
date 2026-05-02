#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

# CommandLineTools-only toolchain lacks the SwiftPM ManifestAPI library, so use
# Xcode's developer dir if available (without changing global xcode-select).
if [[ -z "${DEVELOPER_DIR:-}" ]] && [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
    echo "→ using DEVELOPER_DIR=$DEVELOPER_DIR"
fi

echo "→ swift build (release)"
swift build -c release --product Pulse
swift build -c release --product IconGen

PULSE_BIN=".build/release/Pulse"
ICON_BIN=".build/release/IconGen"
APP="Pulse.app"

if [[ ! -x "$PULSE_BIN" ]]; then
    echo "Build failed: $PULSE_BIN not found" >&2
    exit 1
fi

# 1) Generate iconset PNGs (and OG card for marketing)
echo "→ generating iconset + OG card"
ICONSET_DIR="$(pwd)/AppIcon.iconset"
OG_DIR="$(pwd)/docs/assets"
rm -rf "$ICONSET_DIR"
"$ICON_BIN" "$ICONSET_DIR" --og "$OG_DIR"

# 2) Build .icns
echo "→ building .icns"
ICNS_PATH="$(pwd)/AppIcon.icns"
iconutil --convert icns --output "$ICNS_PATH" "$ICONSET_DIR"

# 3) Bundle the .app
echo "→ bundling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$PULSE_BIN" "$APP/Contents/MacOS/Pulse"
chmod +x "$APP/Contents/MacOS/Pulse"
cp "$ICNS_PATH" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Pulse</string>
    <key>CFBundleIdentifier</key><string>com.altuzar.pulse</string>
    <key>CFBundleName</key><string>Pulse</string>
    <key>CFBundleDisplayName</key><string>Pulse</string>
    <key>CFBundleVersion</key><string>2</string>
    <key>CFBundleShortVersionString</key><string>2.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIconName</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key><true/>
    </dict>
    <key>NSSupportsAutomaticTermination</key><true/>
    <key>NSSupportsSuddenTermination</key><false/>
    <key>NSUserNotificationsUsageDescription</key><string>Get alerts when your connection drops or latency spikes.</string>
    <key>NSHumanReadableCopyright</key><string>Pulse — Your internet, in real time.</string>
</dict>
</plist>
PLIST

# 4) Sign + register
echo "→ ad-hoc codesign"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

# Refresh icon cache so Finder picks up the new icon immediately
touch "$APP" >/dev/null 2>&1 || true

echo
echo "✓ Built $APP ($(du -sh "$APP" | awk '{print $1}'))"
echo
echo "Launch:  open $APP"
echo "Install: cp -R $APP /Applications/"
