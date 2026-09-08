#!/usr/bin/env bash
# Android twin of tool/store_shots.sh: runs the same walkthrough on an emulator
# and grabs a PNG per `SCREENSHOT:<name>` cue with `adb exec-out screencap`.
#
#   tool/store_shots_android.sh <avd-name> <es|en> <out-dir> [extra flutter args...]
#   e.g. tool/store_shots_android.sh Pixel_9_Pro es docs/store/android-raw/es
#
# Play wants a 9:16-ish canvas, so run the captures through
# `tool/store_resize.py` afterwards — see docs/store/README.md.
set -euo pipefail
cd "$(dirname "$0")/.."

AVD="${1:?usage: store_shots_android.sh <avd> <locale> <out-dir>}"
LOCALE="${2:?usage: store_shots_android.sh <avd> <locale> <out-dir>}"
OUT_DIR="${3:?usage: store_shots_android.sh <avd> <locale> <out-dir>}"
shift 3

API_URL="${API_URL:-https://api.opentransit.tech}"
BUNDLE_ID=com.jeronimotech.opentransit
SDK="${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}"
EMULATOR="$SDK/emulator/emulator"
ADB="$(command -v adb || echo "$SDK/platform-tools/adb")"

mkdir -p "$OUT_DIR"

STARTED_EMULATOR=0
SERIAL="$("$ADB" devices | awk '/^emulator-/{print $1; exit}')"
if [[ -z "$SERIAL" ]]; then
  echo ">>> booting $AVD"
  "$EMULATOR" -avd "$AVD" -no-snapshot-save -no-boot-anim -gpu auto >/dev/null 2>&1 &
  STARTED_EMULATOR=1
  "$ADB" wait-for-device
  until [[ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; do sleep 2; done
  SERIAL="$("$ADB" devices | awk '/^emulator-/{print $1; exit}')"
fi
echo ">>> emulator: $SERIAL  locale: $LOCALE  out: $OUT_DIR"

cleanup() {
  if [[ "$STARTED_EMULATOR" == "1" ]]; then
    echo ">>> shutting $SERIAL down"
    "$ADB" -s "$SERIAL" emu kill >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

# A clean demo status bar (the Android equivalent of simctl status_bar).
"$ADB" -s "$SERIAL" shell settings put global sysui_demo_allowed 1 >/dev/null 2>&1 || true
"$ADB" -s "$SERIAL" shell am broadcast -a com.android.systemui.demo -e command enter >/dev/null 2>&1 || true
"$ADB" -s "$SERIAL" shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941 >/dev/null 2>&1 || true
"$ADB" -s "$SERIAL" shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4 >/dev/null 2>&1 || true
"$ADB" -s "$SERIAL" shell am broadcast -a com.android.systemui.demo -e command network -e mobile show -e datatype lte -e level 4 >/dev/null 2>&1 || true
"$ADB" -s "$SERIAL" shell am broadcast -a com.android.systemui.demo -e command battery -e plugged false -e level 100 >/dev/null 2>&1 || true
"$ADB" -s "$SERIAL" shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false >/dev/null 2>&1 || true

# Park the device at Portal Norte and pre-grant location, like the iOS script.
"$ADB" -s "$SERIAL" emu geo fix -74.0459 4.7546 >/dev/null 2>&1 || true
grant() {
  for p in ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION POST_NOTIFICATIONS; do
    "$ADB" -s "$SERIAL" shell pm grant "$BUNDLE_ID" "android.permission.$p" >/dev/null 2>&1 || true
  done
}
grant
( for _ in $(seq 1 60); do sleep 2; grant; done ) &
REGRANT=$!
trap 'kill $REGRANT 2>/dev/null || true; cleanup' EXIT

flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/store_shots_test.dart \
  -d "$SERIAL" \
  --dart-define=API_URL="$API_URL" \
  --dart-define=SHOT_LOCALE="$LOCALE" \
  "$@" 2>&1 | while IFS= read -r line; do
    echo "$line"
    if [[ "$line" == *"SCREENSHOT:"* ]]; then
      name="${line##*SCREENSHOT:}"
      name="${name%%[[:space:]]*}"
      sleep 1.5
      "$ADB" -s "$SERIAL" exec-out screencap -p > "$OUT_DIR/$name.png" && echo ">>> saved $OUT_DIR/$name.png"
    fi
  done

"$ADB" -s "$SERIAL" shell am broadcast -a com.android.systemui.demo -e command exit >/dev/null 2>&1 || true
