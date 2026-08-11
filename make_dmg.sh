#!/usr/bin/env bash
# One-click DMG installer packaging for the Music Alarm macOS app.
# Packages an existing .app bundle into a compressed .dmg using the macOS
# built-in `hdiutil` tool (no external dependencies such as create-dmg).
#
# The DMG contains the app plus an /Applications shortcut, so users can
# drag the app into Applications to install it.
#
# Usage:
#   ./make_dmg.sh [APP_PATH] [DMG_PATH]
#
# Examples:
#   V1:  ./make_dmg.sh                                          # dist/MusicAlarm.app -> dist/MusicAlarm_v1.dmg
#   V2:  ./make_dmg.sh V2/dist/MusicAlarm.app dist/MusicAlarm_v2.dmg
#
#   Defaults:
#     APP_PATH = dist/MusicAlarm.app
#     DMG_PATH = dist/MusicAlarm_v1.dmg
set -euo pipefail

BUILD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APP_PATH="${1:-dist/MusicAlarm.app}"
DMG_PATH="${2:-dist/MusicAlarm_v1.dmg}"

# Resolve paths relative to the repo root unless they are absolute.
case "$APP_PATH" in /*) ;; *) APP_PATH="$BUILD_ROOT/$APP_PATH" ;; esac
case "$DMG_PATH" in /*) ;; *) DMG_PATH="$BUILD_ROOT/$DMG_PATH" ;; esac

APP_DIR="$APP_PATH"
DMG_FINAL="$DMG_PATH"
DIST_DIR="$(dirname "$DMG_FINAL")"
APP_NAME="$(defaults read "$APP_DIR/Contents/Info" CFBundleName 2>/dev/null || basename "$APP_DIR" .app)"
DMG_BASE="$(basename "$DMG_FINAL" .dmg)"

STAGING_DIR="$(mktemp -d)"
TMP_DIR="$(mktemp -d)"
TMP_DMG="$TMP_DIR/$DMG_BASE.dmg"
trap 'rm -rf "$STAGING_DIR" "$TMP_DIR"' EXIT

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}WARN:${NC} $1"; }
fail() { echo -e "${RED}ERROR:${NC} $1"; exit 1; }

info "Music Alarm — DMG packaging"

# 1) Sanity checks -----------------------------------------------------------
if [ ! -d "$APP_DIR" ]; then
  fail "App bundle not found at $APP_DIR. Run ./build.sh (or V2/build.sh) first."
fi
if ! command -v hdiutil >/dev/null 2>&1; then
  fail "hdiutil not found (it ships with macOS)."
fi
if ! command -v ditto >/dev/null 2>&1; then
  fail "ditto not found."
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

# 4) Move the finished image into place --------------------------------------
mkdir -p "$DIST_DIR"
rm -f "$DMG_FINAL"
mv "$TMP_DMG" "$DMG_FINAL"
echo "   DMG written to $DMG_FINAL"

echo ""
echo -e "${GREEN}DMG complete!${NC}"
echo "   Image:  $DMG_FINAL"
echo ""
echo "   Install: open \"$DMG_FINAL\", then drag $APP_NAME.app into Applications."
