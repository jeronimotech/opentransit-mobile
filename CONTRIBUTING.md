# Contributing to opentransit-mobile

Thanks for helping build an open, multi-city trip planner. This document is
short on purpose; the code and tests are the real contract.

## Ground rules

- **Never hardcode a city.** Everything city-specific comes from the API
  (`GET /v1/cities`) or from `assets/fixtures/` in mock mode. If you need a
  Bogotá-only behaviour, put it behind a `City.features` flag.
- **Hand-written models, no codegen.** Each model has a `fromJson` that is
  tolerant to missing/extra fields (`lib/core/models/common.dart` helpers).
  Add a test in `test/models_test.dart` when you add a field.
- **Feature-first layout.** UI lives in `lib/features/<feature>/`; shared code
  in `lib/core/`. A feature may import `core`, never another feature (the
  planner state is the one shared piece and lives in `features/planner/planner_state.dart`).
- **Strings go through ARB.** Add keys to `lib/l10n/app_es.arb` (source of
  truth) and `app_en.arb`, then `flutter gen-l10n`.
- **Mock first.** Every screen must work with `--dart-define=MOCK=true`. If a
  new endpoint is needed, add it to `ApiClient`, `HttpApiClient`,
  `MockApiClient` and a fixture in the same PR.

## Workflow

```bash
flutter pub get
flutter gen-l10n
flutter analyze --fatal-infos   # must be clean
flutter test                    # must be green
flutter run --dart-define=MOCK=true
```

Screenshots for the README are produced by `tool/screenshots.sh` on an iOS
simulator.

## Commit style

Conventional-ish: `feat(planner): …`, `fix(map): …`, `chore: …`. Keep PRs
focused; include a screenshot for UI changes.

## Adding a city

Nothing to do in this repo: once `opentransit-api` serves the city in
`/v1/cities`, it appears in the picker. For demo purposes add a second entry to
`assets/fixtures/cities.json`.
