# Changelog

All notable changes to opentransit-mobile. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.5.0] - 2026-09-06
### Added
- Lote 1 (Citymapper playbook): leave-by countdown on result cards ("Sal en 4 min / Sal ahora / Ya salió") with departed options demoted and an "Actualizar" chip; results grouped by scenario (Más rápido · Menos caminata · Menos transbordos · Más barato · En bici · Taxi / app) with the flat sorts moved to an "Ordenar" menu; the next live departures of each transit leg as tappable chips that re-time the itinerary client-side ("Re-temporizado"); Citymapper-style board rows ("y en 13, 23 min"), contextual empty states and a slim offline/stale/back-online bar; one semantic palette (live green, walk blue, disruption orange, severe red) as a theme extension.
- First-party analytics (v1.5): anonymous, coarsened, batched events posted to `/v1/cities/{city}/events`; session id per start, cohort id rotating every 30 days; opt-out and "Borrar mis estadísticas" in Settings › Privacidad; every screen and action instrumented.

## [1.4.0] - 2026-09-05
### Added
- On-demand mobility (taxi / ride-hailing): "Taxi / app" mode, provider picker with hand-off, tariff estimates.
- TestFlight release tooling: `tool/testflight.sh` (manual signing with an API-key-created certificate/profile in a dedicated keychain, export, upload, wait for processing; `SIGNING=cloud` opt-in), `tool/asc_signing.py` (bundle-id / certificate / profile / builds), `tool/testflight.md`, `ios/ExportOptions*.plist`.
- Real app icon (`assets/icon/icon.png`, generated for iOS and Android via flutter_launcher_icons).
### Changed
- Bundle id / application id `com.jeronimotech.opentransit`; display name "opentransit"; no team id in the Xcode project.
- iOS: `ITSAppUsesNonExemptEncryption=false`, privacy manifest `PrivacyInfo.xcprivacy`, clearer location usage text.
- iOS deployment target raised from 13.0 to 15.0 (App Store Connect warns below 15.0 and rejects from spring 2027).


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
