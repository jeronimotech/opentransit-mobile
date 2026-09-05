# Changelog

All notable changes to opentransit-mobile. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.4.0] - 2026-09-05
### Added
- On-demand mobility (taxi / ride-hailing): "Taxi / app" mode, provider picker with hand-off, tariff estimates.
- TestFlight release tooling: `tool/testflight.sh` (API-key signing, export, upload), `tool/testflight.md`, `ios/ExportOptions.plist`.
- Real app icon (`assets/icon/icon.png`, generated for iOS and Android via flutter_launcher_icons).
### Changed
- Bundle id / application id `com.jeronimotech.opentransit`; display name "opentransit"; no team id in the Xcode project.
- iOS: `ITSAppUsesNonExemptEncryption=false`, privacy manifest `PrivacyInfo.xcprivacy`, clearer location usage text.


## [1.2.0] - 2026-09-04
### Added
- Shared bikes via GBFS: per-city networks, "Bici pública" mode, rental legs with pick-up/drop-off cards, station layer and sheet, nearest-station card, rental fares.

## [1.1.1] - 2026-09-04
### Changed
- Map-first home (peeking sheet, layers button), board-first stop page, single-control planner form.
- Route chip colour blending, headsign clean-up ("A → B"), zoom-based vehicle markers with bearing tick, faint zonal network off by default.

## [1.1.0] - 2026-09-04
### Added
- Home hub, "Ubica tu bus", arrival board, estimated fares, result sorting, typed favorites and recents, follow-along with local notification, POI layer, remote config (forced update, maintenance), App Links / Universal Links, PQRS hand-off.

## [1.0.0] - 2026-09-04
### Added
- First release: city picker, live map, planner, itineraries, stops with departures, routes, alerts, favorites, settings, es/en, dark mode, mock mode.
