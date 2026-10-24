#!/bin/bash
# Builds Bildeimport.app for Apple Silicon and packs it into a DMG.
#
# Usage (on a Mac with Xcode or the Command Line Tools installed):
#   scripts/build-dmg.sh [version]
#
# Result: build/Bildeimport-<version>.dmg
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Bildeimport"
VERSION="${1:-0.1.0}"
VERSION="${VERSION#v}"
BUILD_NUMBER="${GITHUB_RUN_NUMBER:-1}"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
DMG_STAGING="$BUILD_DIR/dmg"
DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION.dmg"

echo "==> Building $APP_NAME $VERSION (build $BUILD_NUMBER) for arm64"
swift build -c release --arch arm64
BINARY="$(swift build -c release --arch arm64 --show-bin-path)/$APP_NAME"

echo "==> Assembling $APP_DIR"
rm -rf "$APP_DIR" "$DMG_STAGING" "$DMG_PATH"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BINARY" "$APP_DIR/Contents/MacOS/$APP_NAME"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUMBER/" Resources/Info.plist > "$APP_DIR/Contents/Info.plist"
printf "APPL????" > "$APP_DIR/Contents/PkgInfo"

echo "==> Making the app icon"
ICONSET="$BUILD_DIR/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" > /dev/null
    double=$((size * 2))
    sips -z "$double" "$double" Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" > /dev/null
done
iconutil -c icns "$ICONSET" -o "$APP_DIR/Contents/Resources/AppIcon.icns"

echo "==> Signing ad hoc (no Apple Developer account)"
codesign --force --deep --sign - --timestamp=none "$APP_DIR"
codesign --verify --verbose "$APP_DIR"

echo "==> Creating $DMG_PATH"
mkdir -p "$DMG_STAGING"
cp -R "$APP_DIR" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Programmer"
# hdiutil sometimes reports "Resource busy" on build machines, so retry a few times.
for attempt in 1 2 3; do
    if hdiutil create \
        -volname "$APP_NAME" \
        -srcfolder "$DMG_STAGING" \
        -fs HFS+ \
        -format UDZO \
        -ov \
        "$DMG_PATH"; then
        break
    fi
    if [ "$attempt" -eq 3 ]; then
        echo "hdiutil failed three times" >&2
        exit 1
    fi
    sleep 5
done

rm -rf "$DMG_STAGING" "$ICONSET"
echo "==> Done: $DMG_PATH"
