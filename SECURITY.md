# Security policy

## Reporting a vulnerability

Please **do not** open a public issue for security problems. Use GitHub's private
vulnerability reporting on this repository ("Security" → "Report a vulnerability"),
or email the maintainers listed in `CODEOWNERS`. We aim to acknowledge within 5 working
days and to publish a fix and advisory once a patch is available.

## Scope

- The Flutter app in this repository (iOS and Android builds).
- Handling of the API base URL, deep links / App Links, local storage of favorites and settings.

The app stores no credentials. It talks only to the opentransit API you configure with
`--dart-define=API_URL=...`; report API-side issues in `opentransit-api`.

## Supported versions

Only the latest release on `main` receives security fixes.
