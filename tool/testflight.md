# Releasing to TestFlight

`tool/testflight.sh` builds, signs, exports and uploads the iOS app with no Xcode UI and no Apple ID
login. It needs a paid Apple Developer Program team and an App Store Connect API key. Nothing
Apple-specific is committed: team id, key and certificates are read from the environment and
private files at build time.

## How signing works (SIGNING=manual, the default)

Xcode's automatic "cloud signing" only works with an **Admin**-role API key; with the usual
**App Manager** key it fails ("Cloud signing permission error" / "No signing certificate iOS
Distribution found"). The script therefore signs manually:

1. `tool/asc_signing.py bundle-id` — get-or-create the bundle id record, enable *Associated Domains*.
2. A 2048-bit RSA key + CSR are generated once in `~/.config/opentransit/apple-dist/` (`dist.key`, `dist.csr`).
3. `tool/asc_signing.py certificate --csr …` — get-or-create an **iOS Distribution** certificate whose
   public key matches that CSR (existing certificates with other keys are left alone).
4. `tool/asc_signing.py profile --cert-id … --install` — get-or-create the **App Store** profile
   "opentransit App Store" and install it under `~/Library/MobileDevice/Provisioning Profiles/`.
5. The certificate + key are packed into `dist.p12` (`openssl pkcs12 -legacy`) and imported into a
   **dedicated keychain** `opentransit-signing` (importing a private key into the login keychain
   prompts a GUI dialog and fails from scripts). Its password and the p12 passphrase are generated
   once and stored in `~/.config/opentransit/keychain.env` (mode 600).
6. `xcodebuild archive` with `CODE_SIGN_STYLE=Manual` + the profile, `xcodebuild -exportArchive` with
   `ios/ExportOptions.manual.plist`, `xcrun altool --upload-app`, then
   `tool/asc_signing.py builds --wait` polls App Store Connect until the build is **VALID**
   (`WAIT_MINUTES`, default 20).

Every step is idempotent: re-running reuses the keychain, key, certificate and profile.
`SIGNING=cloud` keeps the automatic flow for teams whose key has the Admin role.

## One-time setup (Apple side)

1. **Team id** — developer.apple.com → Account → Membership details → *Team ID*.
2. **API key** — App Store Connect → Users and Access → Integrations → *App Store Connect API* →
   Team Keys → Generate, role **App Manager**. Note *Key ID* and *Issuer ID*; download the `.p8`
   **once** and put it at `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8` (mode 600).
3. **App record** — App Store Connect → Apps → **+** → New App: platform iOS, name `opentransit`
   (add the city if the name is taken), primary language Spanish (Colombia), bundle id
   `com.jeronimotech.opentransit` (registered by step 1 above; run
   `tool/asc_signing.py bundle-id` first if it is not in the list), SKU `opentransit-ios`.
   The API cannot create app records; this step is manual.
4. **Testers** — the app → TestFlight → *Internal Testing* → **+** group → add users (team members
   from Users and Access). Internal builds need no review; *External Testing* needs a short beta review.

## Build & upload

```bash
cat > ~/.config/opentransit/apple.env <<'ENV'      # private, never committed
APPLE_TEAM_ID=XXXXXXXXXX
ASC_KEY_ID=XXXXXXXXXX
ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
ENV
chmod 600 ~/.config/opentransit/apple.env

set -a; source ~/.config/opentransit/apple.env; set +a
API_URL=https://api-sandbox-622d.up.railway.app tool/testflight.sh
```

Options: `--no-upload` stops after export (`build/ios/ipa/*.ipa`); `BUILD_NUMBER`, `BUILD_NAME`,
`WEB_HOST`, `WAIT_MINUTES=0`, `SIGNING=cloud` (see the script header). Inspect processing any time
with `tool/asc_signing.py builds`.

On the phone: install **TestFlight** from the App Store, open the invitation e-mail or the group's
public link, install.

## Plist keys and targets

- `ITSAppUsesNonExemptEncryption = false` — only standard HTTPS, so Apple's export-compliance
  question is answered up front and every build is testable immediately.
- `PrivacyInfo.xcprivacy` — Apple's privacy manifest (location for app functionality, no tracking,
  required-reason APIs declared). Plugin manifests are merged by CocoaPods.
- `NSLocationWhenInUseUsageDescription` — shown the first time the app asks for location.
- Deployment target **iOS 15.0** (Podfile, Xcode project, `AppFrameworkInfo.plist`): App Store
  Connect warns on uploads below 15.0 and will reject them from spring 2027.

## Version numbers

`pubspec.yaml` holds `version: 1.4.0+3`. The script sets the build number to "minutes since epoch"
so every upload is strictly increasing; pass `BUILD_NUMBER=` to control it. Bump the version name
in `pubspec.yaml` for releases.

## Troubleshooting

- *Cloud signing permission error* → you are on `SIGNING=cloud` with an App Manager key; use the default.
- *errSecInternalComponent / "User interaction is not allowed"* → the dedicated keychain is locked or
  its partition list is missing; delete `~/Library/Keychains/opentransit-signing.keychain-db` and re-run
  (the certificate is re-imported from `apple-dist/dist.p12`).
- *No profile for 'com.jeronimotech.opentransit'* → run `tool/asc_signing.py profile --cert-id <id> --install`;
  if the profile was invalidated (new certificate), the script deletes and recreates it.
- *Associated Domains* capability missing → `tool/asc_signing.py bundle-id` enables it.
- *altool: Unable to authenticate* → key file not at `~/.appstoreconnect/private_keys/`, or wrong issuer id.
- *Build stuck in PROCESSING* → Apple is slow; `tool/asc_signing.py builds --wait --version <n> --timeout 40`.
