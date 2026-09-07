# Changelog

All notable changes to opentransit-mobile. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.6.0] - 2026-09-06
### Added
- Lote 2: Casa ⇄ Trabajo card on Home (direction by hour, manual invert, leave-by countdown, route chip, "Ruta con desvío · Replanear" when an active alert names a route the trip uses); "Cuándo salir" sheet fed by `GET /plan/forecast` (one row per departure time, recommended option highlighted, long gaps called out) with a client-side fallback for older APIs; per-route alert schedules (Siempre · Solo días hábiles · Solo horario laboral · Nunca) raising local notifications, deduped by (route, alert) and capped at three per route per day; line page with live buses snapped to the stop timeline, a live count and "GO rápido" from any stop.
- Lote 3: GO keeps a persistent, silent notification with the current leg and arrival time, vibrates on "bájate en la próxima", detects going off route (>150 m from the leg's shape for 45 s) and offers a re-plan from the current position, and ends with a receipt (planned vs actual, distance, estimated cost, CO₂ saved vs driving); "Compartir viaje" publishes the itinerary behind a random token and pushes progress every 30 s while GO runs, with coordinates coarsened to ~110 m before they leave the device and a write key that never does.
- Native splash screen on both platforms (brand red with a dark variant, app glyph, no text; Android 12+ SplashScreen API and an iOS LaunchScreen storyboard), handed over on the first frame so it costs no startup time.
### Fixed
- GO no longer touches Riverpod's `ref` while unmounting: the analytics summary is captured while the screen is alive, which also stopped a "Using ref when a widget is about to or has been unmounted" crash after the receipt.

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
