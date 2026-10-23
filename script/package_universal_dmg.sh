#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BUILD_DIR="$ROOT_DIR/.build/universal"
PRODUCT_DIR="$BUILD_DIR/out/Products/Release"
APP_BUNDLE="$ROOT_DIR/dist/universal/NeonTetris.app"
DMG_PATH="$ROOT_DIR/dist/NeonStack-universal.dmg"
mkdir -p "$BUILD_DIR" "$ROOT_DIR/dist"
STAGE_DIR="$(mktemp -d "$BUILD_DIR/dmg-stage.XXXXXX")"
trap 'rm -rf "$STAGE_DIR"' EXIT

# 构建独立目录，避免覆盖开发版应用包或中断正在进行的对局。
swift build -c release --arch arm64 --arch x86_64 --scratch-path "$BUILD_DIR"
ARCHITECTURES="$(lipo -archs "$PRODUCT_DIR/NeonTetris")"
[[ " $ARCHITECTURES " == *' arm64 '* && " $ARCHITECTURES " == *' x86_64 '* ]]

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$PRODUCT_DIR/NeonTetris" "$APP_BUNDLE/Contents/MacOS/NeonTetris"
cp "$ROOT_DIR/Assets/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
cp -R "$PRODUCT_DIR/NeonTetris_NeonTetris.bundle" "$APP_BUNDLE/Contents/Resources/"
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>NeonTetris</string>
<key>CFBundleIdentifier</key><string>com.nglife.neon-tetris</string>
<key>CFBundleName</key><string>Neon Stack</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>15.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>GCSupportsMultipleMicroGamepads</key><true/>
</dict></plist>
PLIST

# SwiftPM 资源包和外层应用分别签名，保证复制进 DMG 后仍可验证。
codesign --force --sign - "$APP_BUNDLE/Contents/Resources/NeonTetris_NeonTetris.bundle"
codesign --force --sign - "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

cp -R "$APP_BUNDLE" "$STAGE_DIR/Neon Stack.app"
ln -s /Applications "$STAGE_DIR/Applications"
hdiutil create -quiet -volname 'Neon Stack' -srcfolder "$STAGE_DIR" -ov -format UDZO "$DMG_PATH"
hdiutil verify "$DMG_PATH"
shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"
echo "$DMG_PATH"
