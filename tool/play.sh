#!/usr/bin/env bash
# Build, sign and publish the Android app to Google Play. The twin of tool/testflight.sh.
#
#   tool/play.sh                       # internal testing track
#   PLAY_TRACK=production tool/play.sh
#   tool/play.sh --no-upload           # stop after the signed bundle
#
# Required (keep in a private file, e.g. ~/.config/opentransit/play.env, mode 600):
#   GOOGLE_PLAY_SERVICE_ACCOUNT  path to the Play service-account JSON
# Optional:
#   PLAY_TRACK      internal | alpha | beta | production   (default internal)
#   PLAY_ROLLOUT    staged rollout fraction for production, e.g. 0.1
#   PLAY_DRAFT      1 to attach the build without releasing it
#   API_URL         API the build points at           (default https://api.opentransit.tech)
#   BUILD_NUMBER    versionCode                       (default: minutes since epoch, always rising)
#   BUILD_NAME      versionName                       (default: the version in pubspec.yaml)
#   NOTES_DIR       directory of <locale>.txt release notes (default docs/store/release-notes)
#
# Signing comes from android/key.properties, which points at a keystore outside the repository.
# Play App Signing re-signs the bundle with the key Google holds, so this one is the upload key only.
set -euo pipefail
cd "$(dirname "$0")/.."

NO_UPLOAD=0
[[ "${1:-}" == "--no-upload" ]] && NO_UPLOAD=1

ENV_FILE="${PLAY_ENV:-$HOME/.config/opentransit/play.env}"
# shellcheck disable=SC1090
[[ -f "$ENV_FILE" ]] && { set -a; source "$ENV_FILE"; set +a; }

API_URL="${API_URL:-https://api.opentransit.tech}"
TRACK="${PLAY_TRACK:-internal}"
BUILD_NUMBER="${BUILD_NUMBER:-$(( $(date +%s) / 60 ))}"
BUILD_NAME="${BUILD_NAME:-$(sed -n 's/^version: *\([0-9.]*\).*/\1/p' pubspec.yaml)}"
NOTES_DIR="${NOTES_DIR:-docs/store/release-notes}"
KEY="${GOOGLE_PLAY_SERVICE_ACCOUNT:-$HOME/.config/opentransit/play-service-account.json}"

echo "==> opentransit Android $BUILD_NAME ($BUILD_NUMBER) · track $TRACK · API $API_URL"

[[ -f android/key.properties ]] || {
  echo "android/key.properties is missing: the release build would be signed with the debug key," >&2
  echo "and Play rejects that. See tool/releasing.md for where the signing material lives." >&2
  exit 1
}

flutter build appbundle --release \
  --dart-define="API_URL=$API_URL" \
  --dart-define="APP_VERSION=$BUILD_NAME" \
  --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER"

AAB="build/app/outputs/bundle/release/app-release.aab"
[[ -f "$AAB" ]] || { echo "no bundle at $AAB" >&2; exit 1; }
OUT="build/opentransit-$BUILD_NAME-$BUILD_NUMBER.aab"
cp "$AAB" "$OUT"
echo "==> $OUT ($(du -h "$OUT" | cut -f1))"

if [[ "$NO_UPLOAD" == 1 ]]; then
  echo "==> --no-upload: stopping here"
  exit 0
fi

[[ -f "$KEY" ]] || {
  echo "no Play service account at $KEY." >&2
  echo "Create one in Google Cloud for the project linked to Play Console, give it 'Release to" >&2
  echo "testing tracks' under Users and permissions, and point GOOGLE_PLAY_SERVICE_ACCOUNT at it." >&2
  exit 1
}

ARGS=(--aab "$OUT" --track "$TRACK" --name "$BUILD_NAME" --key "$KEY")
[[ -d "$NOTES_DIR" ]] && ARGS+=(--notes-from "$NOTES_DIR")
[[ -n "${PLAY_ROLLOUT:-}" ]] && ARGS+=(--rollout "$PLAY_ROLLOUT")
[[ "${PLAY_DRAFT:-0}" == "1" ]] && ARGS+=(--draft)

tool/play_publish.py "${ARGS[@]}"
echo "==> done. tool/play_publish.py --status shows what each track is serving."
