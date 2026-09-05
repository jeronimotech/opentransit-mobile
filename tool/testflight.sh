#!/usr/bin/env bash
# Build, sign, export and upload the iOS app to TestFlight — without opening Xcode.
#
# Required environment (never commit these; keep them in a private env file and `source` it):
#   APPLE_TEAM_ID    10-character Apple Developer team id (developer.apple.com → Membership)
#   ASC_KEY_ID       App Store Connect API key id   (App Store Connect → Users and Access → Integrations)
#   ASC_ISSUER_ID    App Store Connect API issuer id (same page, shown above the key list)
# Optional:
#   ASC_KEY_PATH     path to the AuthKey_<ASC_KEY_ID>.p8 file
#                    (default ~/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8 — altool also looks there)
#   API_URL          opentransit API the build talks to (default https://api-sandbox-622d.up.railway.app)
#   WEB_HOST         web host for Universal Links (default: value baked in the entitlements)
#   BUILD_NUMBER     CFBundleVersion (default: minutes since epoch, always increasing)
#   BUILD_NAME       CFBundleShortVersionString (default: version from pubspec.yaml)
#
# Usage:
#   tool/testflight.sh              build + export + upload
#   tool/testflight.sh --no-upload  stop after the .ipa is exported (build/ios/ipa/)
#
# Automatic signing with `-allowProvisioningUpdates` and the API key lets xcodebuild register the
# bundle id, create the distribution certificate/profile and sign without an Apple ID logged into Xcode.
set -euo pipefail

cd "$(dirname "$0")/.."

UPLOAD=1
[[ "${1:-}" == "--no-upload" ]] && UPLOAD=0

: "${APPLE_TEAM_ID:?set APPLE_TEAM_ID}"
: "${ASC_KEY_ID:?set ASC_KEY_ID}"
: "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}"
ASC_KEY_PATH="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8}"
[[ -f "$ASC_KEY_PATH" ]] || { echo "API key file not found: $ASC_KEY_PATH" >&2; exit 1; }

API_URL="${API_URL:-https://api-sandbox-622d.up.railway.app}"
WEB_HOST="${WEB_HOST:-}"
BUILD_NUMBER="${BUILD_NUMBER:-$(( $(date +%s) / 60 ))}"
BUILD_NAME="${BUILD_NAME:-$(sed -n 's/^version: *\([0-9.]*\).*/\1/p' pubspec.yaml)}"

ARCHIVE=build/ios/archive/Runner.xcarchive
EXPORT_DIR=build/ios/ipa
EXPORT_PLIST=build/ios/ExportOptions.plist

echo "==> opentransit iOS $BUILD_NAME ($BUILD_NUMBER) · team $APPLE_TEAM_ID · API $API_URL"

flutter pub get >/dev/null
DEFINES=(--dart-define="API_URL=$API_URL")
[[ -n "$WEB_HOST" ]] && DEFINES+=(--dart-define="WEB_HOST=$WEB_HOST")
flutter build ios --release --no-codesign "${DEFINES[@]}" \
  --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER"

echo "==> archive"
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" archive \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  -authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" | tail -n 5

echo "==> export"
mkdir -p "$(dirname "$EXPORT_PLIST")"
sed "s/__TEAM_ID__/$APPLE_TEAM_ID/" ios/ExportOptions.plist > "$EXPORT_PLIST"
# Xcode < 15.4 only knows "app-store"
XCODE_MAJOR=$(xcodebuild -version | sed -n 's/^Xcode \([0-9]*\).*/\1/p')
if [[ "$XCODE_MAJOR" -lt 15 ]]; then
  plutil -replace method -string app-store "$EXPORT_PLIST"
fi
rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_PLIST" -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" | tail -n 3

IPA=$(ls "$EXPORT_DIR"/*.ipa | head -n 1)
echo "==> exported $IPA ($(du -h "$IPA" | cut -f1))"

if [[ "$UPLOAD" -eq 1 ]]; then
  echo "==> upload to App Store Connect"
  mkdir -p "$HOME/.appstoreconnect/private_keys"
  [[ -f "$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8" ]] || \
    cp "$ASC_KEY_PATH" "$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
  xcrun altool --upload-app -f "$IPA" -t ios --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
  echo "==> uploaded. Processing takes ~10–20 min; then it appears under TestFlight → iOS builds."
else
  echo "==> --no-upload: skipped upload"
fi
