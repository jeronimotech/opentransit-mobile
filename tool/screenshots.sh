#!/usr/bin/env bash
# Runs the screenshot walkthrough on an iOS simulator and captures a PNG each
# time the integration test prints a `SCREENSHOT:<name>` cue.
#
#   tool/screenshots.sh [simulator-udid] [target] [extra flutter args...]
#   e.g. tool/screenshots.sh "" integration_test/live_api_test.dart --dart-define=API_URL=http://localhost:8001
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE="${1:-}"
DEVICE="${DEVICE:-$(xcrun simctl list devices booted -j | python3 -c 'import sys,json;d=json.load(sys.stdin)["devices"];print(next(x["udid"] for v in d.values() for x in v if x["state"]=="Booted"))')}"
TARGET="${2:-integration_test/screenshots_test.dart}"
shift $(( $# > 2 ? 2 : $# ))
OUT=docs/screenshots
mkdir -p "$OUT"

# Pre-grant location so the system prompt never covers the app, and park the
# simulated device at Portal Norte.
BUNDLE_ID=tech.jeronimo.opentransit
xcrun simctl privacy "$DEVICE" grant location "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl privacy "$DEVICE" grant location-always "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl location "$DEVICE" set 4.7546,-74.0459 >/dev/null 2>&1 || true

flutter drive \
  --driver=test_driver/integration_test.dart \
  --target="$TARGET" \
  -d "$DEVICE" "$@" 2>&1 | while IFS= read -r line; do
    echo "$line"
    if [[ "$line" == *"SCREENSHOT:"* ]]; then
      name="${line##*SCREENSHOT:}"
      name="${name%%[[:space:]]*}"
      sleep 1.5
      xcrun simctl io "$DEVICE" screenshot "$OUT/$name.png" >/dev/null 2>&1 && echo ">>> saved $OUT/$name.png"
    fi
  done
