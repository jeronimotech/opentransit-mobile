# Releasing to TestFlight

`tool/testflight.sh` builds, signs, exports and uploads the iOS app with no Xcode UI. It needs a
paid Apple Developer Program team and an App Store Connect API key. Nothing Apple-specific is
committed to the repo: the team id and key are read from the environment at build time.

## One-time setup (Apple side)

1. **Team id** — developer.apple.com → Account → Membership details → *Team ID* (10 characters).
2. **API key** — appstoreconnect.apple.com → Users and Access → Integrations → *App Store Connect API*
   → Team Keys → Generate. Role **App Manager**. Note the *Key ID* and the *Issuer ID* (top of the
   page) and download the `.p8` **once** (Apple never shows it again). Put it at
   `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8` (mode 600).
3. **App record** — App Store Connect → Apps → **+** → New App:
   - Platform iOS · Name `opentransit` (must be unique on the store; add the city if taken)
   - Primary language Spanish (Colombia) · Bundle ID `tech.jeronimo.opentransit`
     (appears in the list after the first archive registers it; otherwise register it first at
     developer.apple.com → Certificates, Identifiers & Profiles → Identifiers, capability
     *Associated Domains* enabled) · SKU `opentransit-ios`.
   - The API cannot create app records; this step is manual.
4. **Testers** — App Store Connect → the app → TestFlight → *Internal Testing* → **+** group
   (e.g. "Core") → add users (they must be members of the team, App Store Connect → Users and Access).
   Internal builds need no review. For people outside the team use *External Testing*
   (first build goes through a short beta review).

## Build & upload

```bash
# private file, never committed
cat > ~/.config/opentransit/apple.env <<'ENV'
APPLE_TEAM_ID=XXXXXXXXXX
ASC_KEY_ID=XXXXXXXXXX
ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
ENV
chmod 600 ~/.config/opentransit/apple.env

set -a; source ~/.config/opentransit/apple.env; set +a
API_URL=https://api-sandbox-622d.up.railway.app tool/testflight.sh
```

Options: `--no-upload` stops after export (`build/ios/ipa/opentransit.ipa`); `BUILD_NUMBER`,
`BUILD_NAME`, `WEB_HOST` override the defaults (see the script header).

Processing takes 10–20 minutes after upload; the build then appears under TestFlight → iOS builds.
Add it to the internal group and testers get the TestFlight push. On the phone: install
**TestFlight** from the App Store, open the invitation, install.

## Why these plist keys

- `ITSAppUsesNonExemptEncryption = false` — the app only uses standard HTTPS, so Apple's export-compliance
  question is answered up front and every build becomes available for testing immediately.
- `PrivacyInfo.xcprivacy` — Apple's privacy manifest: location is used for app functionality only,
  no tracking, and the two "required reason" APIs the app touches (UserDefaults via
  shared_preferences, file timestamps via the Flutter engine) are declared. Plugin manifests are
  merged by CocoaPods at build time.
- `NSLocationWhenInUseUsageDescription` — shown by iOS the first time the app asks for location.

## Version numbers

`pubspec.yaml` holds `version: 1.4.0+3` (name+build). The script sets the build number to
"minutes since epoch" by default so every upload is strictly increasing; pass `BUILD_NUMBER=` to
control it. Bump the version name in `pubspec.yaml` for releases.

## Troubleshooting

- *No profiles for 'tech.jeronimo.opentransit'* → the first archive with `-allowProvisioningUpdates`
  registers the bundle id and creates the profile; make sure the API key has App Manager role.
- *Associated Domains* capability missing → enable it on the identifier at developer.apple.com, or
  temporarily remove `ios/Runner/Runner.entitlements` from the target for the first build.
- *altool: Unable to authenticate* → key file not at `~/.appstoreconnect/private_keys/`, or wrong issuer id.
