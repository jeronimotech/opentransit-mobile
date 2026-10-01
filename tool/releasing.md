# Releasing to the stores

Two scripts, one per store: `tool/testflight.sh` for iOS and `tool/play.sh` for Android. Neither
needs a browser, an Apple ID login or the Play Console UI.

# iOS: TestFlight

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

## Companion targets (Live Activity, Apple Watch)

`tool/testflight.sh` calls `tool/xcode_targets.rb` before building, so a fresh
checkout gets the three companion targets without anyone opening Xcode. Each
embedded bundle needs its own App Store profile; `COMPANION_PROFILES` maps them:

```
com.jeronimotech.opentransit.LiveActivity              -> opentransit LiveActivity App Store
com.jeronimotech.opentransit.watchkitapp               -> opentransit watchkitapp App Store
com.jeronimotech.opentransit.watchkitapp.complications -> opentransit watch complications App Store
```

Create or refresh them the same way as the app's own profile:

```bash
set -a; source ~/.config/opentransit/apple.env; set +a
CERT=$(BUNDLE_ID=com.jeronimotech.opentransit python3 tool/asc_signing.py \
        certificate --csr ~/.config/opentransit/apple-dist/dist.csr | python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])')
BUNDLE_ID=com.jeronimotech.opentransit.LiveActivity \
  python3 tool/asc_signing.py profile --cert-id "$CERT" --name "opentransit LiveActivity App Store" --install
```

If the export fails with "no profile for …", that bundle id is the one missing.


## Submitting to App Store review

`asc_signing.py appstore` prepares the App Store version and sends it to review. Uploading the binary
is still `tool/testflight.sh`; this attaches a build that is already processed.

```bash
set -a; source ~/.config/opentransit/apple.env; set +a

tool/asc_signing.py appstore --status                 # versions and review submissions
tool/asc_signing.py appstore --version 1.15.0 --build 29 \
  --notes-from docs/store/release-notes               # prepare, do not submit
tool/asc_signing.py appstore --version 1.15.0 --build 29 \
  --notes-from docs/store/release-notes --submit      # and send it to review
```

`--release-type` defaults to `MANUAL`, so an approved version waits for you to release it rather than
going live the moment Apple says yes. `AFTER_APPROVAL` is the other sensible choice.

Three things about Apple's model that the errors do not explain well:

- **Only one version can be editable at a time.** Creating an app leaves a placeholder behind (1.0,
  never submitted), so the first real run renames it rather than refusing over a version string
  nobody chose. It says so when it does.
- **Release notes can only be set for languages the app already publishes.** opentransit publishes
  `en-US` and `es-MX`; the other five need to be created in App Store Connect with their full
  metadata first, and until then those locales are skipped with a line in the log. Note also that the
  notes directory is named after Play's locale codes, so they are mapped on the way in: `es-419` →
  `es-MX`, `it-IT` → `it`, `ms-MY` → `ms`, `ar` → `ar-SA`.
- **Submission goes through a `reviewSubmission`,** not the old `appStoreVersionSubmissions`
  endpoint, which Apple deprecated and which now rejects apps that have used the new flow.

What it does not do: the description, keywords, screenshots and the app review contact. Apple blocks a
submission whose metadata is incomplete and names the field, so the first run will tell you what is
missing. Export compliance needs no call — `ios/Runner/Info.plist` already declares
`ITSAppUsesNonExemptEncryption`.

---

# Releasing to Google Play

`tool/play.sh` is the Android twin: it builds, signs, uploads and puts the build on a track, with no
Play Console UI. `tool/play_publish.py` is the API client underneath, usable on its own.

```bash
cat > ~/.config/opentransit/play.env <<'ENV'      # private, never committed
GOOGLE_PLAY_SERVICE_ACCOUNT=/Users/you/.config/opentransit/play-service-account.json
ENV
chmod 600 ~/.config/opentransit/play.env

tool/play.sh                          # internal testing
PLAY_TRACK=production tool/play.sh    # production
PLAY_TRACK=production PLAY_ROLLOUT=0.1 tool/play.sh   # 10 % staged rollout
tool/play_publish.py --status         # what each track is serving
```

## One-time setup (Google side)

1. **Play Console account, as an organization.** 25 USD once. Google verifies the organization,
   usually against a D-U-N-S number, and that takes days — start it before you need it. An
   organization account also avoids the twenty-testers-for-fourteen-days rule that applies to new
   personal accounts.
2. **Create the app in the Play Console UI and upload the first bundle there.** The API cannot
   create an app, and a 404 from it on a package that exists in the UI usually means this step is
   still pending.
3. **A service account.** Play Console → *Users and permissions* → *Invite new user* accepts a
   service-account email, and Google Cloud is where the account and its key are created. The role
   needs *Release to testing tracks* at minimum, or *Release to production* for the production
   track. The Cloud project holding the account must be linked under Play Console → *API access*.
4. **Download the JSON key once** and put it beside the other credentials, mode 600. It can publish
   releases to every app in the account, so treat it like the APNs key.

## What it does and does not do

Signing is the upload key in `android/key.properties`; Play App Signing re-signs with the key Google
holds, which is why losing the local keystore is survivable. The uploader never touches the store
listing, the screenshots, the Data safety answers or the content rating: those live in the Console,
and a release whose listing is incomplete will not commit.

Play's API applies changes through an **edit**: you open one, attach the bundle and the track, and
commit. An uncommitted edit changes nothing, and an edit goes stale if the app is touched elsewhere
meanwhile — so a failed commit is worth retrying from a fresh edit rather than debugging. A failure
here discards the edit on the way out.

Release notes come from `docs/store/release-notes/<locale>.txt`, one file per published language.
Play refuses a commit that has no notes for a language the listing is live in.
