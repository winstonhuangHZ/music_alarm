#!/usr/bin/env bash
# One-click DMG installer packaging for the Music Alarm macOS app.
# Packages dist/MusicAlarm.app into dist/MusicAlarm_v1.dmg using the
# macOS built-in `hdiutil` tool (no external dependencies such as create-dmg).
#
# Usage:
#   ./make_dmg.sh                 # defaults: app=MusicAlarm, dmg=MusicAlarm_v1
#   ./make_dmg.sh <AppName> <DmgName>
#
# The DMG contains the app plus an /Applications shortcut, so users can
# drag the app into Applications to install it.
set -euo pipefail

APP_NAME="${1:-MusicAlarm}"
DMG_NAME="${2:-MusicAlarm_v1}"
BUILD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="$BUILD_ROOT/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$DMG_NAME.dmg"

STAGING_DIR="$(mktemp -d)"
TMP_DIR="$(mktemp -d)"
TMP_DMG="$TMP_DIR/$DMG_NAME.dmg"
trap 'rm -rf "$STAGING_DIR" "$TMP_DIR"' EXIT

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}WARN:${NC} $1"; }
fail() { echo -e "${RED}ERROR:${NC} $1"; exit 1; }

info "Music Alarm — DMG packaging"

# 1) Sanity checks -----------------------------------------------------------
if [ ! -d "$APP_DIR" ]; then
  fail "App bundle not found at $APP_DIR. Run ./build.sh first."
fi
if ! command -v hdiutil >/dev/null 2>&1; then
  fail "hdiutil not found (it ships with macOS)."
fi

# 2) Stage the app with an /Applications shortcut ---------------------------
info "Staging $APP_NAME.app + Applications shortcut..."
mkdir -p "$STAGING_DIR"
ditto "$APP_DIR" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

# 3) Create a compressed UDZO read-only image -------------------------------
info "Creating DMG with hdiutil (UDZO, zlib-9)..."
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$TMP_DMG"
echo "   Raw DMG created."

# 4) Move the finished image into dist/ --------------------------------------
mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"
mv "$TMP_DMG" "$DMG_PATH"
echo "   DMG moved to $DMG_PATH"

echo ""
echo -e "${GREEN}DMG complete!${NC}"
echo "   Image:  $DMG_PATH"
echo ""
echo "   Install: open \"$DMG_PATH\", then drag $APP_NAME.app into Applications."
