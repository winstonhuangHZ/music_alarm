#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TEST_BINARY="$(mktemp -t music-alarm-smoke).x86_64"
trap 'rm -f "$TEST_BINARY"' EXIT

SWIFT_FILES=()
while IFS= read -r swift_file; do
  SWIFT_FILES+=("$swift_file")
done < <(find Sources -name '*.swift' ! -name 'main.swift' -print | sort)

swiftc -O -swift-version 5 \
  -target x86_64-apple-macos11.0 \
  -framework SwiftUI -framework AppKit -framework AVFoundation \
  -framework CoreAudio \
  -framework CryptoKit -framework Combine \
  -framework MediaPlayer -framework UserNotifications -framework Carbon -framework AppIntents \
  -framework WebKit \
  -o "$TEST_BINARY" "${SWIFT_FILES[@]}" Tests/SharedAlarmStorageSmoke.swift
"$TEST_BINARY"

python3 - <<'PY'
from pathlib import Path
import re

source_keys = set()
for path in Path("Sources").rglob("*.swift"):
    source_keys.update(re.findall(r'L\("((?:[^"\\]|\\.)*)"\)', path.read_text()))

for path in sorted(Path("Localizations").glob("*.lproj/Localizable.strings")):
    keys = set(re.findall(r'^"((?:[^"\\]|\\.)*)"\s*=', path.read_text(), re.M))
    missing = sorted(source_keys - keys)
    if missing:
        raise SystemExit(f"{path}: missing localization keys: {missing}")

print(f"localization parity passed ({len(source_keys)} keys)")
PY

required_labels=(
  'accessibilityLabel(L("Test Alarm"))'
  'accessibilityLabel(L("Add Alarm"))'
  'accessibilityLabel(L("Stop"))'
  'accessibilityLabel(L("I am really awake"))'
  'accessibilityLabel(L("Reliability Check"))'
)
for label in "${required_labels[@]}"; do
  rg -Fq "$label" Sources || {
    echo "missing accessibility coverage: $label" >&2
    exit 1
  }
done

echo "accessibility source smoke passed"
