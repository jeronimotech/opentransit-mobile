#!/usr/bin/env bash
# Captures the App Store / Google Play walkthrough on one simulator, in one
# language, against the production API.
#
#   tool/store_shots.sh <device-name-or-udid> <es|en> <out-dir> [extra flutter args...]
#   e.g. tool/store_shots.sh "iPhone 17 Pro Max" es docs/store/ios/es
#
# It boots the simulator, forces its system language, pins the status bar to a
# clean 9:41 / full-signal state, runs `integration_test/store_shots_test.dart`
# through `tool/screenshots.sh`, and shuts the simulator back down if it was
# not already running when we started.
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE_NAME="${1:?usage: store_shots.sh <device> <locale> <out-dir>}"
LOCALE="${2:?usage: store_shots.sh <device> <locale> <out-dir>}"
OUT_DIR="${3:?usage: store_shots.sh <device> <locale> <out-dir>}"
shift 3

API_URL="${API_URL:-https://api.opentransit.tech}"

case "$LOCALE" in
  es) LANG_CODE="es-CO"; LOCALE_ID="es_CO" ;;
  en) LANG_CODE="en-US"; LOCALE_ID="en_US" ;;
  *)  echo "unsupported locale: $LOCALE (use es or en)" >&2; exit 2 ;;
esac

# Resolve a device name to a udid (last match wins → newest runtime listed).
if [[ "$DEVICE_NAME" =~ ^[0-9A-F-]{36}$ ]]; then
  UDID="$DEVICE_NAME"
else
  UDID=$(xcrun simctl list devices available -j | python3 -c "
import sys, json
name = sys.argv[1]
devs = json.load(sys.stdin)['devices']
hits = [d['udid'] for rt in sorted(devs) for d in devs[rt] if d['name'] == name]
if not hits:
    sys.exit('no available simulator named ' + repr(name))
print(hits[-1])
" "$DEVICE_NAME")
fi
echo ">>> device: $DEVICE_NAME ($UDID)  locale: $LOCALE  out: $OUT_DIR"

WAS_BOOTED=$(xcrun simctl list devices -j | python3 -c "
import sys, json
u = sys.argv[1]
devs = json.load(sys.stdin)['devices']
print(next((d['state'] for rt in devs for d in devs[rt] if d['udid'] == u), 'Unknown'))
" "$UDID")

cleanup() {
  xcrun simctl status_bar "$UDID" clear >/dev/null 2>&1 || true
  if [[ "$WAS_BOOTED" != "Booted" ]]; then
    echo ">>> shutting $UDID back down"
    xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

# System language has to be written while the device is off, otherwise
# SpringBoard rewrites it on shutdown.
xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
PREFS="$HOME/Library/Developer/CoreSimulator/Devices/$UDID/data/Library/Preferences/.GlobalPreferences.plist"
mkdir -p "$(dirname "$PREFS")"
[[ -f "$PREFS" ]] || /usr/libexec/PlistBuddy -c "Save" "$PREFS" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Delete :AppleLanguages" "$PREFS" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Add :AppleLanguages array" "$PREFS" >/dev/null
/usr/libexec/PlistBuddy -c "Add :AppleLanguages:0 string $LANG_CODE" "$PREFS" >/dev/null
/usr/libexec/PlistBuddy -c "Set :AppleLocale $LOCALE_ID" "$PREFS" >/dev/null 2>&1 \
  || /usr/libexec/PlistBuddy -c "Add :AppleLocale string $LOCALE_ID" "$PREFS" >/dev/null

xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || true

# A clean marketing status bar (Apple's own screenshots use 9:41).
xcrun simctl status_bar "$UDID" override \
  --time "9:41" \
  --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 \
  --batteryState charged --batteryLevel 100 >/dev/null 2>&1 || true

OUT="$OUT_DIR" tool/screenshots.sh "$UDID" integration_test/store_shots_test.dart \
  --dart-define=API_URL="$API_URL" \
  --dart-define=SHOT_LOCALE="$LOCALE" \
  "$@"
