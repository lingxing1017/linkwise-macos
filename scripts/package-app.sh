#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="拾链"
EXECUTABLE_NAME="Linkwise"
BUILD_CONFIG="release"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

cd "$ROOT_DIR"
swift build -c "$BUILD_CONFIG" --product LinkwiseApp

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
cp "$ROOT_DIR/.build/$BUILD_CONFIG/LinkwiseApp" "$MACOS_DIR/$EXECUTABLE_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Linkwise</string>
    <key>CFBundleIdentifier</key>
    <string>local.linkwise.macos</string>
    <key>CFBundleName</key>
    <string>拾链</string>
    <key>CFBundleDisplayName</key>
    <string>拾链</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>拾链保存链接</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>linkwise</string>
            </array>
        </dict>
    </array>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>拾链需要读取当前浏览器标签页标题和 URL，用于保存当前页面为书签。</string>
</dict>
</plist>
PLIST

echo "Created $APP_DIR"
