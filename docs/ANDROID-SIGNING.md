# Signing the Android app for release

Google Play rejects an app signed with the debug key, and until this was set up that is
exactly what `flutter build appbundle --release` produced. The signing material never
enters the repository.

## How it is wired

`android/app/build.gradle.kts` reads `android/key.properties` if it exists:

- **present** → the release build is signed with the upload key it names.
- **absent** → the release build falls back to the debug key.

The fallback is deliberate. Anyone can clone this and build, and CI does not need the
keystore; a build made without it simply cannot be uploaded, which is the honest outcome.

`android/key.properties`, `*.jks` and `*.keystore` are gitignored. Verify with
`git check-ignore -v android/key.properties` before committing anything near them.

## The keystore

Created 2026-09-08, RSA 4096, valid 10 000 days (to 2054 — Play requires at least 2033).

```
~/.config/opentransit/opentransit-upload.jks     the keystore     (mode 600)
~/.config/opentransit/android-signing.env        its password     (mode 600)
~/.config/opentransit/... → android/key.properties points at both (mode 600, gitignored)
```

**Losing this file is not fatal, but only because Play App Signing is used**: Google holds
the actual app signing key and this is only the *upload* key, which can be reset through
Play Console. Back it up anyway; resetting costs days.

To recreate `android/key.properties` on another machine:

```bash
set -a; . ~/.config/opentransit/android-signing.env; set +a
cat > android/key.properties <<EOF
storeFile=$ANDROID_KEYSTORE
storePassword=$ANDROID_KEYSTORE_PASSWORD
keyAlias=$ANDROID_KEY_ALIAS
keyPassword=$ANDROID_KEYSTORE_PASSWORD
EOF
chmod 600 android/key.properties
```

## Verifying a build is really signed

```bash
flutter build appbundle --release
JH="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
"$JH/bin/jarsigner" -verify -certs build/app/outputs/bundle/release/app-release.aab | grep CN=
```

It must name `CN=Jeronimo SAS`. If it says `CN=Android Debug`, `key.properties` was not
found and the bundle cannot be uploaded.

## App Links and the two fingerprints

`assetlinks.json`, served by the web app, must list **every** certificate that signs an
installed build:

| key | SHA-256 | where it comes from |
|---|---|---|
| upload | `79:33:7A:…:C2:35` | this keystore; signs what we send to Play |
| Play App Signing | not yet known | Google generates it at the first upload |

Until the app is uploaded only the upload key is configured, which verifies locally
installed builds. **After the first upload**, copy the app signing fingerprint from Play
Console → Setup → App signing and append it to `ANDROID_CERT_SHA256` on the web service,
comma-separated. Without it, links will not open the app for anyone who installed it from
Play, and nothing will report an error.
