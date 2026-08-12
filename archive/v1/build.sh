#!/usr/bin/env bash
# One-click universal (arm64 + x86_64) build & package script for the Music Alarm macOS app.
# Produces ./dist/MusicAlarm.app — a fat/universal binary on toolchains that support both
# architectures (Xcode 12+ / Swift 5.3+). On older toolchains it falls back to whatever
# architectures it can compile and prints a warning.
#
# Usage:
#   ./build.sh                     # build all ARCHS (default: arm64 x86_64)
#   ARCHS="x86_64" ./build.sh      # build only x86_64
#   ARCHS="arm64" ./build.sh       # build only arm64
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

# Architectures to build. Override with: ARCHS="x86_64" ./build.sh
ARCHS="${ARCHS:-arm64 x86_64}"
# Minimum macOS version (must match LSMinimumSystemVersion in Info.plist)
MIN_MACOS="11.0"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}WARN:${NC} $1"; }

info "Music Alarm — universal build & package script"
info "Target architectures: $ARCHS"
info "Cleaning previous build..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

info "Compiling Swift sources with swiftc..."
SWIFT_FILES=$(find "$SRC_DIR" -name '*.swift' | sort)

# Compile for a single architecture. Prefers the modern target triple
# (arm64/x86_64-apple-macos11.0); falls back to the legacy 10.15 triple for old
# toolchains (e.g. Xcode 11 Command Line Tools) that reject the "macos11.0" form.
compile_arch() {
  local arch="$1" target
  for t in "$arch-apple-macos${MIN_MACOS}" "$arch-apple-macosx10.15"; do
    if swiftc -O -swift-version 5 \
        -target "$t" \
        -framework SwiftUI \
        -framework AppKit \
        -framework AVFoundation \
        -framework Combine \
        -o "$TMP_DIR/$APP_NAME-$arch" \
        $SWIFT_FILES 2>"$TMP_DIR/$arch.err"; then
      echo "   [$arch] compiled OK (target: $t)."
      return 0
    fi
  done
  echo "   [$arch] FAILED:" >&2
  sed 's/^/       /' "$TMP_DIR/$arch.err" >&2 || true
  return 1
}

THIN_BINARIES=()
for arch in $ARCHS; do
  if compile_arch "$arch"; then
    THIN_BINARIES+=("$TMP_DIR/$APP_NAME-$arch")
  else
    warn "Compilation failed for $arch; skipping this architecture."
  fi
done

if [ "${#THIN_BINARIES[@]}" -eq 0 ]; then
  echo "ERROR: no architecture compiled successfully." >&2
  exit 1
fi

if [ "${#THIN_BINARIES[@]}" -eq 1 ]; then
  warn "Only one architecture built (${THIN_BINARIES[0]##*-}); this is NOT a universal binary."
  cp "${THIN_BINARIES[0]}" "$MACOS_DIR/$APP_NAME"
else
  info "Merging universal binary with lipo..."
  lipo -create "${THIN_BINARIES[@]}" -output "$MACOS_DIR/$APP_NAME"
  lipo -info "$MACOS_DIR/$APP_NAME" || true
fi
echo "   Binary: $MACOS_DIR/$APP_NAME"

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
