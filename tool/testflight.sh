#!/usr/bin/env bash
# Build, sign, export and upload the iOS app to TestFlight — no Xcode UI, no Apple ID login.
#
# Signing modes
#   SIGNING=manual (default)  A distribution certificate and an App Store profile are created through
#                             the App Store Connect API (works with an API key of role "App Manager"),
#                             the identity lives in a DEDICATED keychain, and xcodebuild signs manually.
#   SIGNING=cloud             Xcode automatic "cloud signing" with the API key. Needs an Admin-role key;
#                             with App Manager keys Xcode fails with "Cloud signing permission error".
#
# Required environment (keep in a private file, e.g. ~/.config/opentransit/apple.env, mode 600):
#   APPLE_TEAM_ID     10-character team id
#   ASC_KEY_ID        App Store Connect API key id
#   ASC_ISSUER_ID     App Store Connect issuer id
# Optional:
#   ASC_KEY_PATH      AuthKey_<ASC_KEY_ID>.p8 (default ~/.appstoreconnect/private_keys/AuthKey_<id>.p8)
#   BUNDLE_ID         default: PRODUCT_BUNDLE_IDENTIFIER of the Runner target in the Xcode project
#   PROFILE_NAME      App Store profile name (default "opentransit App Store")
#   DIST_DIR          where the distribution key/CSR/cert/p12 live (default ~/.config/opentransit/apple-dist)
#   DIST_P12_PASSWORD passphrase of dist.p12; generated and stored in $KEYCHAIN_ENV when the p12 is created
#   KEYCHAIN_NAME     dedicated keychain (default opentransit-signing)
#   KEYCHAIN_PW       its password; read from $KEYCHAIN_ENV when unset, generated on first creation
#   KEYCHAIN_ENV      file holding KEYCHAIN_PW / DIST_P12_PASSWORD (default ~/.config/opentransit/keychain.env)
#   API_URL           opentransit API baked into the build (default https://api-sandbox-622d.up.railway.app)
#   WEB_HOST          web host for Universal Links
#   BUILD_NUMBER      CFBundleVersion (default: minutes since epoch — always increasing)
#   BUILD_NAME        CFBundleShortVersionString (default: version from pubspec.yaml)
#   WAIT_MINUTES      how long to wait for App Store Connect processing (default 20; 0 = don't wait)
#
# Usage:
#   tool/testflight.sh              prepare signing, build, archive, export, upload, wait for VALID
#   tool/testflight.sh --no-upload  stop after the .ipa is exported (build/ios/ipa/)
#
# Why a dedicated keychain: importing a private key into the login keychain prompts a GUI dialog
# and fails non-interactively; a keychain we own can be unlocked and partition-listed from a script.
# Nothing here prints key material.
set -euo pipefail
export LANG="${LANG:-en_US.UTF-8}"   # CocoaPods needs a UTF-8 locale
cd "$(dirname "$0")/.."

UPLOAD=1
[[ "${1:-}" == "--no-upload" ]] && UPLOAD=0

: "${APPLE_TEAM_ID:?set APPLE_TEAM_ID}"
: "${ASC_KEY_ID:?set ASC_KEY_ID}"
: "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}"
ASC_KEY_PATH="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8}"
[[ -f "$ASC_KEY_PATH" ]] || { echo "API key file not found: $ASC_KEY_PATH" >&2; exit 1; }
export ASC_KEY_PATH APPLE_TEAM_ID

SIGNING="${SIGNING:-manual}"
BUNDLE_ID="${BUNDLE_ID:-$(grep -oE 'PRODUCT_BUNDLE_IDENTIFIER = [^;]+' ios/Runner.xcodeproj/project.pbxproj \
  | grep -v RunnerTests | head -n 1 | sed 's/.*= //')}"
export BUNDLE_ID
PROFILE_NAME="${PROFILE_NAME:-opentransit App Store}"
DIST_DIR="${DIST_DIR:-$HOME/.config/opentransit/apple-dist}"
KEYCHAIN_NAME="${KEYCHAIN_NAME:-opentransit-signing}"
KEYCHAIN_ENV="${KEYCHAIN_ENV:-$HOME/.config/opentransit/keychain.env}"
KEYCHAIN_PATH="$HOME/Library/Keychains/$KEYCHAIN_NAME.keychain-db"
API_URL="${API_URL:-https://api-sandbox-622d.up.railway.app}"
WEB_HOST="${WEB_HOST:-}"
BUILD_NUMBER="${BUILD_NUMBER:-$(( $(date +%s) / 60 ))}"
BUILD_NAME="${BUILD_NAME:-$(sed -n 's/^version: *\([0-9.]*\).*/\1/p' pubspec.yaml)}"
WAIT_MINUTES="${WAIT_MINUTES:-20}"

ARCHIVE=build/ios/archive/Runner.xcarchive
EXPORT_DIR=build/ios/ipa
EXPORT_PLIST=build/ios/ExportOptions.plist
ASC="python3 tool/asc_signing.py"

echo "==> opentransit iOS $BUILD_NAME ($BUILD_NUMBER) · $BUNDLE_ID · team $APPLE_TEAM_ID · signing $SIGNING · API $API_URL"

# ------------------------------------------------------------------ secrets file helpers
load_env_file() { [[ -f "$KEYCHAIN_ENV" ]] && { set -a; # shellcheck disable=SC1090
  source "$KEYCHAIN_ENV"; set +a; } || true; }
save_env_var() { # name value → appended to $KEYCHAIN_ENV (mode 600), replacing an existing line
  mkdir -p "$(dirname "$KEYCHAIN_ENV")"; touch "$KEYCHAIN_ENV"; chmod 600 "$KEYCHAIN_ENV"
  grep -v "^$1=" "$KEYCHAIN_ENV" > "$KEYCHAIN_ENV.tmp" || true
  printf '%s=%s\n' "$1" "$2" >> "$KEYCHAIN_ENV.tmp"; mv "$KEYCHAIN_ENV.tmp" "$KEYCHAIN_ENV"; chmod 600 "$KEYCHAIN_ENV"
}
json_field() { python3 -c 'import json,sys; d=json.load(sys.stdin); print(d[sys.argv[1]] or "")' "$1"; }

# ------------------------------------------------------------------ manual signing preparation
prepare_manual_signing() {
  load_env_file
  mkdir -p "$DIST_DIR"; chmod 700 "$DIST_DIR"

  # 1. dedicated keychain
  if [[ ! -f "$KEYCHAIN_PATH" ]]; then
    if [[ -z "${KEYCHAIN_PW:-}" ]]; then KEYCHAIN_PW=$(openssl rand -hex 24); save_env_var KEYCHAIN_PW "$KEYCHAIN_PW"; fi
    echo "==> creating keychain $KEYCHAIN_NAME"
    security create-keychain -p "$KEYCHAIN_PW" "$KEYCHAIN_PATH"
    security set-keychain-settings "$KEYCHAIN_PATH"          # no auto-lock
  fi
  : "${KEYCHAIN_PW:?KEYCHAIN_PW not set and not found in $KEYCHAIN_ENV}"
  security unlock-keychain -p "$KEYCHAIN_PW" "$KEYCHAIN_PATH"
  # keep it in the search list next to the login keychain (idempotent)
  # shellcheck disable=SC2046
  security list-keychains -d user -s "$KEYCHAIN_PATH" $(security list-keychains -d user | tr -d '" ' | grep -v "$KEYCHAIN_NAME")

  # 2. private key + CSR (created once, never leave $DIST_DIR)
  if [[ ! -f "$DIST_DIR/dist.key" ]]; then
    echo "==> generating distribution key + CSR"
    openssl genrsa -out "$DIST_DIR/dist.key" 2048 2>/dev/null; chmod 600 "$DIST_DIR/dist.key"
    openssl req -new -key "$DIST_DIR/dist.key" -out "$DIST_DIR/dist.csr" \
      -subj "/CN=opentransit iOS Distribution/O=$APPLE_TEAM_ID/C=CO"
  fi

  # 3. bundle id, certificate (matching our key) and profile via the App Store Connect API
  echo "==> App Store Connect: bundle id"
  $ASC bundle-id > build/asc-bundle.json
  echo "==> App Store Connect: distribution certificate"
  $ASC certificate --csr "$DIST_DIR/dist.csr" --out "$DIST_DIR/dist.cer" > build/asc-cert.json
  CERT_ID=$(json_field id < build/asc-cert.json)
  echo "==> App Store Connect: profile \"$PROFILE_NAME\""
  $ASC profile --cert-id "$CERT_ID" --name "$PROFILE_NAME" --install > build/asc-profile.json
  PROFILE_UUID=$(json_field uuid < build/asc-profile.json)

  # 4. import the identity into the dedicated keychain if it is not there yet
  openssl x509 -inform DER -in "$DIST_DIR/dist.cer" -out "$DIST_DIR/dist.pem" 2>/dev/null
  CERT_CN=$(openssl x509 -in "$DIST_DIR/dist.pem" -noout -subject -nameopt RFC2253 | sed -n 's/.*CN=\([^,]*\).*/\1/p')
  if ! security find-identity -v -p codesigning "$KEYCHAIN_PATH" | grep -q "$CERT_CN"; then
    echo "==> importing identity into $KEYCHAIN_NAME"
    if [[ -z "${DIST_P12_PASSWORD:-}" ]]; then DIST_P12_PASSWORD=$(openssl rand -hex 16); save_env_var DIST_P12_PASSWORD "$DIST_P12_PASSWORD"; fi
    # -legacy: macOS `security import` cannot read PKCS12 files written with OpenSSL 3 defaults
    openssl pkcs12 -export -legacy -inkey "$DIST_DIR/dist.key" -in "$DIST_DIR/dist.pem" \
      -out "$DIST_DIR/dist.p12" -passout "pass:$DIST_P12_PASSWORD" -name "$CERT_CN"
    chmod 600 "$DIST_DIR/dist.p12"
    security import "$DIST_DIR/dist.p12" -k "$KEYCHAIN_PATH" -P "$DIST_P12_PASSWORD" \
      -T /usr/bin/codesign -T /usr/bin/security -T /usr/bin/productbuild >/dev/null
    # Apple's WWDR intermediate must be present or codesign reports an untrusted chain
    security find-certificate -c "Apple Worldwide Developer Relations" "$KEYCHAIN_PATH" >/dev/null 2>&1 || {
      curl -fsSL https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer -o build/wwdr.cer
      security import build/wwdr.cer -k "$KEYCHAIN_PATH" >/dev/null; }
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PW" "$KEYCHAIN_PATH" >/dev/null
  fi
  SIGN_IDENTITY_PREFIX=$(echo "$CERT_CN" | sed 's/:.*//')   # "Apple Distribution" or "iPhone Distribution"
  echo "==> signing identity: $CERT_CN · profile $PROFILE_NAME ($PROFILE_UUID)"
}

# ------------------------------------------------------------------ build
# Flutter caches native-asset builds (e.g. objective_c.framework from the
# `objective_c` package) under build/native_assets and reuses them across
# targets: after a simulator run the cached arm64 slice is a *simulator* binary
# and App Store Connect rejects the upload (ITMS-91169 "references an
# unsupported platform in the arm64 slice"). Deleting only build/ is not enough
# (.dart_tool still marks the assets as up to date and the Xcode copy phase then
# finds nothing), so start from a clean tree: everything is rebuilt for the device.
flutter clean >/dev/null
mkdir -p build
flutter pub get >/dev/null
DEFINES=(--dart-define="API_URL=$API_URL")
[[ -n "$WEB_HOST" ]] && DEFINES+=(--dart-define="WEB_HOST=$WEB_HOST")
flutter build ios --release --no-codesign "${DEFINES[@]}" --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER"

XCODE_MAJOR=$(xcodebuild -version | sed -n 's/^Xcode \([0-9]*\).*/\1/p')

if [[ "$SIGNING" == "manual" ]]; then
  prepare_manual_signing
  echo "==> archive (manual signing, Runner target only)"
  # Manual signing must apply to the Runner target ONLY: passing CODE_SIGN_STYLE /
  # PROVISIONING_PROFILE_SPECIFIER on the xcodebuild command line overrides every
  # target, and CocoaPods targets refuse a provisioning profile ("… does not
  # support provisioning profiles"). So the Runner Release/Profile build settings
  # are patched in the project for the archive and restored afterwards; only the
  # team and the keychain flag stay global (harmless for pods).
  PBXPROJ=ios/Runner.xcodeproj/project.pbxproj
  cp "$PBXPROJ" build/project.pbxproj.bak
  restore_pbxproj() { [[ -f build/project.pbxproj.bak ]] && mv build/project.pbxproj.bak "$PBXPROJ"; }
  trap restore_pbxproj EXIT
  PBXPROJ="$PBXPROJ" BUNDLE_ID="$BUNDLE_ID" APPLE_TEAM_ID="$APPLE_TEAM_ID" \
  SIGN_IDENTITY_PREFIX="$SIGN_IDENTITY_PREFIX" PROFILE_NAME="$PROFILE_NAME" python3 - <<'PY'
import os, re
p = os.environ["PBXPROJ"]; s = open(p).read()
want = {
    "CODE_SIGN_STYLE": "Manual",
    "DEVELOPMENT_TEAM": os.environ["APPLE_TEAM_ID"],
    '"CODE_SIGN_IDENTITY[sdk=iphoneos*]"': '"%s"' % os.environ["SIGN_IDENTITY_PREFIX"],
    "PROVISIONING_PROFILE_SPECIFIER": '"%s"' % os.environ["PROFILE_NAME"],
}
n = 0
def patch(m):
    global n
    block = m.group(0)
    if "PRODUCT_BUNDLE_IDENTIFIER = %s;" % os.environ["BUNDLE_ID"] not in block: return block
    if not re.search(r"name = (Release|Profile);", block): return block
    for k, v in want.items():
        line = "\t\t\t\t%s = %s;" % (k, v)
        pat = re.compile(r"^\t\t\t\t%s = [^;]*;$" % re.escape(k), re.M)
        block = pat.sub(line, block) if pat.search(block) else block.replace("\t\t\t\tbuildSettings = {\n", "\t\t\t\tbuildSettings = {\n" + line + "\n", 1)
    n += 1
    return block
s = re.sub(r"\t\t[0-9A-F]{24} /\* (Release|Profile) \*/ = \{\n\t\t\tisa = XCBuildConfiguration;.*?\n\t\t\};", patch, s, flags=re.S)
open(p, "w").write(s)
print("==> patched %d Runner build configuration(s) for manual signing" % n)
assert n >= 1, "Runner Release configuration not found in project.pbxproj"
PY
  xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release \
    -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" archive \
    DEVELOPMENT_TEAM="$APPLE_TEAM_ID" OTHER_CODE_SIGN_FLAGS="--keychain $KEYCHAIN_PATH" | tail -n 5
  restore_pbxproj; trap - EXIT
  echo "==> export (manual)"
  sed -e "s/__TEAM_ID__/$APPLE_TEAM_ID/" -e "s/__BUNDLE_ID__/$BUNDLE_ID/" \
      -e "s/__PROFILE_NAME__/$PROFILE_NAME/" -e "s/__CERT__/$SIGN_IDENTITY_PREFIX/" \
      ios/ExportOptions.manual.plist > "$EXPORT_PLIST"
  [[ "$XCODE_MAJOR" -lt 15 ]] && plutil -replace method -string app-store "$EXPORT_PLIST"
  rm -rf "$EXPORT_DIR"
  xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_PLIST" | tail -n 3
else
  echo "==> archive (cloud signing; needs an Admin-role API key)"
  xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release \
    -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" archive \
    DEVELOPMENT_TEAM="$APPLE_TEAM_ID" CODE_SIGN_STYLE=Automatic \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
    -authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" \
    -authenticationKeyIssuerID "$ASC_ISSUER_ID" | tail -n 5
  echo "==> export (cloud)"
  sed "s/__TEAM_ID__/$APPLE_TEAM_ID/" ios/ExportOptions.plist > "$EXPORT_PLIST"
  [[ "$XCODE_MAJOR" -lt 15 ]] && plutil -replace method -string app-store "$EXPORT_PLIST"
  rm -rf "$EXPORT_DIR"
  xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_PLIST" -allowProvisioningUpdates \
    -authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" \
    -authenticationKeyIssuerID "$ASC_ISSUER_ID" | tail -n 3
fi

IPA=$(ls "$EXPORT_DIR"/*.ipa | head -n 1)
echo "==> exported $IPA ($(du -h "$IPA" | cut -f1))"

# ------------------------------------------------------------------ upload + processing
if [[ "$UPLOAD" -eq 1 ]]; then
  echo "==> upload to App Store Connect"
  mkdir -p "$HOME/.appstoreconnect/private_keys"
  [[ -f "$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8" ]] || \
    cp "$ASC_KEY_PATH" "$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
  xcrun altool --upload-app -f "$IPA" -t ios --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
  if [[ "$WAIT_MINUTES" != "0" ]]; then
    echo "==> waiting for App Store Connect to process build $BUILD_NUMBER (up to $WAIT_MINUTES min)"
    $ASC builds --wait --version "$BUILD_NUMBER" --build-name "$BUILD_NAME" --timeout "$WAIT_MINUTES"
    echo "==> build $BUILD_NAME ($BUILD_NUMBER) is VALID — add it to a TestFlight group in App Store Connect."
  else
    echo "==> uploaded; processing takes ~10–20 min (check with: tool/asc_signing.py builds)"
  fi
else
  echo "==> --no-upload: skipped upload"
fi
