#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/dist/Music Alarm.app}"

[[ -d "$APP_PATH" ]] || {
  echo "Build the app first: $ROOT_DIR/build.sh" >&2
  exit 1
}

open "$APP_PATH"
sleep 2

osascript <<'APPLESCRIPT'
tell application "System Events"
    tell process "MusicAlarm"
        if not (exists window 1) then error "Music Alarm has no accessible window"
        set windowDescription to description of window 1
        if windowDescription is missing value then error "Main window has no accessibility description"
    end tell
end tell
APPLESCRIPT

echo "UI accessibility smoke passed"
