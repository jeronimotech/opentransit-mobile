# Changelog

All notable changes to opentransit-mobile. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## 1.10.0 — "Pregúntame"

### Added
- **Conversational assistant, phase 1 (text)** — a chat sheet reachable from the search pill and from the home action row. Ask "¿cómo llego al centro?" or "¿hay desvíos hoy?" and the answer comes back as prose *and* as the app's own widgets: an itinerary card you can tap into the results screen, an arrival board, an alert, a stop, a route chip. The model never answers from memory; the API makes it call our tools and write from what they return.
- Cards land **before** the prose, as the contract requires, so something useful is on screen while the sentence is still being written.
- A "pensando…" line that names the tool in words — "buscando rutas…", "revisando desvíos…" — never a function name. An unknown tool falls back to the plain wording rather than leaking `plan_trip` into the UI.
- Suggested prompts on first open, deliberately city-neutral: nothing in the shipped strings names one city's stations.
- A one-time notice per session naming the provider the city configured, read from the city payload.
- Plain sentences for every refusal the endpoint documents (budget exhausted, rate limited, provider down, assistant off). The code itself is never shown.
- A stop button: a reply in flight can be abandoned, keeping the prose that already arrived.

### Privacy
- **Chat text never enters analytics.** The only event is `assistant_query` with `{toolsUsed, latencyMs, ok}`; a failure emits `error` with its code and the screen. Neither the question nor where it was asked can be reconstructed from either.
- Only role and text go back up with the next question. Cards, ids and errors stay on the device.
- The assistant **never raises a location prompt**: it uses the position only if the user already granted it, and rounds it to three decimals (~110 m) first, which is what makes the notice's promise true.
- The conversation lives in memory only. Closing the sheet keeps it, closing the app loses it, and changing city starts a new one.

### Changed
- The home action row gains a fourth chip, "Pregúntame", and the search pill a small button. Both are hidden when the city has the assistant off **or** the device is offline — the model answers only from our tools, so a chat with no API is a dead end.
- `MockApiClient` answers chat with canned intents (trip, next bus, alerts, refusal, "I can't do that"), so the sheet and every state are reachable with no API and no key.

### Fixed
- **Duplicate departure-chip keys.** The itinerary detail keyed its "next departures here" chips by timestamp, and the live Bogotá feed predicts two buses of the same route for the same second. Duplicate keys inside a `Wrap` throw, which took the whole screen down in debug and aborted the live walkthrough. Keyed by position now.
- Geocoder ranking upstream (`opentransit-api`): a multi-word query now prefers an exact name match, so "Parque de la 93" no longer plans from the station "Parque".

### Notes
- The live walkthrough no longer aborts on a debug-only framework assertion, and a failure to scroll the settings screen degrades to a less precise screenshot instead of ending a 20-minute run.

## 1.9.0 — "Cerca de mí"

### Added
- **"Cerca de mí"**, a live map *mode* rather than a layer: the map follows you, a ring shows the radius you chose (300 m · 600 m · 1 km, remembered), and a sheet lists the buses inside it nearest first, each with its route chip, component and distance. Reached from the "Cerca de ti" header on the home sheet, from the Capas popover, and at `/{city}/live` (the deep link `?near=me` still works).
- Component filters (Troncal · Zonal · Alimentador · Dual · Cable), remembered between sessions, so a corridor like la Caracas can be cut down to what you actually ride.
- An approaching/leaving arrow derived from the vehicle's bearing against the bearing to you. Feeds without a bearing — Bogotá's among them today — get no arrow at all rather than a guess.
- Selecting a bus frames you and it together, highlights it and draws its route faintly.
- Empty state that says which radius came up empty and widens it in one tap.

### Fixed
- **A leaking vehicle stream.** `_liveFrames` was an `async*` generator with `await for` inside a retry loop, and cancelling such a generator only takes effect at its next `yield`. While the feed was quiet — a stalled connection, or Bogotá after the last service — the upstream subscription stayed open after the screen was gone. It now owns its subscription and cancels immediately. This affected the home map too, not only the new mode.
- The component filters no longer scroll horizontally with the last chips off-screen; they wrap, like the planner's modes.

## 1.8.0 — Wear OS and Android Live Updates

### Added
- **Wear OS app** (Wear OS 4+, `android/wear/`, Compose for Wear) with the same three screens as the Apple Watch app: *Cerca de ti*, *Ubica tu bus* and a GO mirror that taps the wrist when it is time to get off.
- **Tile** with the pinned stop's next departures, one swipe from the watch face.
- **Phone bridge for Android**: `WatchDataLayerBridge` answers the same `opentransit/watch` channel as the iOS side and writes a Wearable Data Layer data item, so `WatchSync` is now genuinely platform-agnostic instead of iOS-only.
- The watch falls back to calling `GET /watch/summary` itself when the phone is out of range, caches the last board and always shows its age.
- **Live Updates on Android 16**: the GO notification is styled with `Notification.ProgressStyle` and asks to be promoted to the lock screen, the platform's answer to the Live Activity.

### Changed
- The GO notification now reads like the Live Activity — "Bájate en {parada} · {n} min · llegas {hora}" — from the same numbers, so the phone, the watch and the lock screen never disagree.

### Notes
- The wear module is deliberately not a dependency of `:app`; `flutter build apk` is unaffected and the watch app is built and installed on its own.
- `setRequestPromotedOngoing` exists only in API 36.1 while Flutter pins `compileSdk` to 36, so it is invoked reflectively rather than dragging the whole app to a newer platform for one optional flag.

## 1.7.0 — Live Activities and Apple Watch

### Added
- **Live Activity + Dynamic Island** for a trip in progress: route chip, "Bájate en {parada} · {n} min", progress and ETA on the lock screen; compact, expanded and minimal Dynamic Island presentations; tapping deep-links back into the trip. Started by GO, updated locally on every leg or ETA change, ended on arrival or cancel.
- **Apple Watch app** (watchOS 10+) with *Cerca de ti*, *Ubica tu bus* and a GO mirror that taps the wrist when it is time to get off. Data arrives from the phone over WatchConnectivity and falls back to a direct call to `/watch/summary`; the last board is cached and its age is shown.
- **Complications** (corner, circular, rectangular, inline) counting down to the next departure of the pinned stop, refreshed through WidgetKit timelines.
- `tool/xcode_targets.rb`: idempotent, reproducible creation of the three native targets.

### Fixed
- Watch wire models decode leniently. Swift's synthesized `Decodable` throws on a missing key even when the property has a default, so one field the phone did not send blanked the entire watch.
- `tool/screenshots.sh` re-applies the simulator location grant during the run; `flutter drive` reinstalls the app and dropped it, leaving the system dialog on top of the screenshot.

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
