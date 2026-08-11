#!/usr/bin/env bash
# One-click build & package script for the Music Alarm macOS app.
# Produces ./dist/MusicAlarm.app
set -euo pipefail

APP_NAME="MusicAlarm"
BUNDLE_ID="com.musicalarm.app"
BUILD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="$BUILD_ROOT/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
SRC_DIR="$BUILD_ROOT/Sources"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}WARN:${NC} $1"; }

info "Music Alarm — build & package script"
info "Cleaning previous build..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

info "Compiling Swift sources with swiftc..."
cd "$BUILD_ROOT"
SWIFT_FILES=$(find "$SRC_DIR" -name '*.swift' | sort)
swiftc -O -swift-version 5 \
  -framework SwiftUI \
  -framework AppKit \
  -framework AVFoundation \
  -framework Combine \
  -o "$MACOS_DIR/$APP_NAME" \
  $SWIFT_FILES
echo "   Compilation OK."

info "Copying Info.plist..."
cp "$BUILD_ROOT/Info.plist" "$CONTENTS/Info.plist"

info "Generating app icon..."
if command -v iconutil >/dev/null 2>&1; then
  if swiftc -O scripts/generate_icon.swift -framework AppKit -o "$TMP_DIR/genicon" >/dev/null 2>&1 \
     && "$TMP_DIR/genicon" "$TMP_DIR/icon-1024.png" >/dev/null 2>&1 \
     && [ -f "$TMP_DIR/icon-1024.png" ]; then
    ICONSET="$TMP_DIR/AppIcon.iconset"
    mkdir -p "$ICONSET"
    sips -z 16 16 "$TMP_DIR/icon-1024.png" --out "$ICONSET/icon_16x16.png" >/dev/null
    sips -z 32 32 "$TMP_DIR/icon-1024.png" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
    sips -z 32 32 "$TMP_DIR/icon-1024.png" --out "$ICONSET/icon_32x32.png" >/dev/null
    sips -z 64 64 "$TMP_DIR/icon-1024.png" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
    sips -z 128 128 "$TMP_DIR/icon-1024.png" --out "$ICONSET/icon_128x128.png" >/dev/null
    sips -z 256 256 "$TMP_DIR/icon-1024.png" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
    sips -z 256 256 "$TMP_DIR/icon-1024.png" --out "$ICONSET/icon_256x256.png" >/dev/null
    sips -z 512 512 "$TMP_DIR/icon-1024.png" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
    sips -z 512 512 "$TMP_DIR/icon-1024.png" --out "$ICONSET/icon_512x512.png" >/dev/null
    cp "$TMP_DIR/icon-1024.png" "$ICONSET/icon_512x512@2x.png"
    iconutil -c icns "$ICONSET" -o "$RESOURCES_DIR/AppIcon.icns"
    echo "   App icon installed."
  else
    warn "Icon generation skipped (iconutil available but generator failed)."
  fi
else
  warn "iconutil not found; skipping app icon."
fi

info "Ad-hoc code signing..."
if codesign --force --deep --sign - "$APP_DIR" 2>/dev/null; then
  echo "   Signed OK."
else
  warn "codesign failed; app is still runnable locally."
fi

echo ""
echo -e "${GREEN}Build complete!${NC}"
echo "   App:     $APP_DIR"
echo "   Binary:  $MACOS_DIR/$APP_NAME"
echo ""
echo "   To launch:  open \"$APP_DIR\""
