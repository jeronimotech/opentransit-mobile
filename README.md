# opentransit-mobile

[![CI](https://github.com/jeronimotech/opentransit-mobile/actions/workflows/ci.yml/badge.svg)](https://github.com/jeronimotech/opentransit-mobile/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE) [![Docs](https://img.shields.io/badge/docs-jeronimotech.github.io%2Fopentransit-informational)](https://jeronimotech.github.io/opentransit/)


Open-source, multi-city, multimodal public-transport trip planner for iOS and
Android. Part of the **opentransit** project together with
[`opentransit-api`](https://github.com/jeronimotech/opentransit-api) (FastAPI + OpenTripPlanner) and
[`opentransit-web`](https://github.com/jeronimotech/opentransit-web) (Next.js). First city: **Bogotá**
(TransMilenio / SITP, GTFS + GTFS-Realtime).

Flutter 3.41 · Dart 3.11 · MapLibre · Riverpod · go_router · MIT.

**v1.1.1 "map first"** — the map is the product: it keeps ≥ 65 % of the screen,
the sheet peeks with three actions and the stops near you, and the live fleet
only appears once you zoom into a district.

| Home (map first) | Sheet dragged up | Street zoom: live buses | Planner form | Stop: board first |
|---|---|---|---|---|
| ![](docs/screenshots/02_home_map.png) | ![](docs/screenshots/03_home_sheet.png) | ![](docs/screenshots/04_home_live_zoom.png) | ![](docs/screenshots/05_plan_form.png) | ![](docs/screenshots/08_stop_board.png) |

| Ubica tu bus | Results (sorted) | Itinerary + fare | Favorites | Dark mode + POIs |
|---|---|---|---|---|
| ![](docs/screenshots/03_locate_bus.png) | ![](docs/screenshots/06_results_sorted.png) | ![](docs/screenshots/07_itinerary_fare.png) | ![](docs/screenshots/10_favorites.png) | ![](docs/screenshots/12_home_dark.png) |

**v1.2 — shared bikes (GBFS).** Any number of bike-share networks per city,
all from `city.mobility.bikeShare[]` (name, colour, app links, pricing): a
"Bici pública" chip in the planner, rental legs with pickup / drop-off station
cards and live availability, the stations layer with counts on the map, and the
nearest station in "Cerca de ti".

| Planner: Bici pública | Results with a rental leg | Pickup / drop-off cards | Stations layer | Station sheet |
|---|---|---|---|---|
| ![](docs/screenshots/bike_01_plan_form.png) | ![](docs/screenshots/bike_02_results.png) | ![](docs/screenshots/bike_03_itinerary.png) | ![](docs/screenshots/bike_04_home_stations.png) | ![](docs/screenshots/bike_05_station_sheet.png) |

More: [city picker](docs/screenshots/01_city_picker.png) · [route detail](docs/screenshots/09_route_detail.png) · [alerts](docs/screenshots/11_alerts.png) · [forced update](docs/screenshots/12_forced_update.png) · [v1.1 hub screens](docs/screenshots/v1.1/) · [v1 screens](docs/screenshots/v1/)

Against the real Bogotá API (`opentransit-api` on port 8001, live GTFS-RT, ~5,800 buses):

| Live home | Live street zoom | Live itinerary | Live station board | Live "Ubica tu bus" |
|---|---|---|---|---|
| ![](docs/screenshots/live_01_home.png) | ![](docs/screenshots/live_02_home_zoom.png) | ![](docs/screenshots/live_04_itinerary.png) | ![](docs/screenshots/live_05_stop_board.png) | ![](docs/screenshots/live_06_next_buses.png) |

Shared bikes against the live Tembici Bogotá GBFS feed (252 stations, via the API):

| Bike-only plan | Rental itinerary | Bike + bus request | Stations layer | Station sheet |
|---|---|---|---|---|
| ![](docs/screenshots/live_bike_02_results.png) | ![](docs/screenshots/live_bike_03_itinerary.png) | ![](docs/screenshots/live_bike_04_results_mixed.png) | ![](docs/screenshots/live_bike_06_home_stations.png) | ![](docs/screenshots/live_bike_07_station_sheet.png) |

Note: with `TRANSIT,WALK,BIKE_RENTAL` the router currently returns transit-only
itineraries for long trips (rental as access/egress is an OpenTripPlanner
tuning matter on the API side); bike-only requests return rental legs.

## What it does

**v1.1 — the best of TransMi App and Maas, on open data** (see the plan in the
workspace `ROADMAP-v1.1.md`):

- **Map-first home** — full-bleed map with a floating search pill, one
  **Capas** button (Buses en vivo · Servicios · Red de rutas [trunk/cable
  backbone, on] · Rutas zonales [off by default: they overlap heavily]) and
  locate. The
  sheet peeks at 24 % with three actions (Planear viaje · Ubica tu bus · Buscar
  ruta) and a "Cerca de ti" strip of the nearest stops with their next two
  buses; Casa/Trabajo, recent trips, the alert carousel (severity-sorted,
  dismissible, max 3 impressions per alert) and the city's partner hand-off
  tiles (`services[]`) appear when you drag it up. Snap points 24 / 55 / 92 %.
- **Live fleet by zoom** — hidden below zoom 14 (a hint says to zoom in),
  small translucent dots between 14 and 16, larger dots with a bearing tick and
  the route label from 16; colours desaturated 20 % so the base map stays
  readable; positions interpolated between frames (off with reduce-motion).
- **Route chips** — feed colour blended 35 % toward the component colour and
  clamped to ≥ 4.5:1 contrast; neon feed colours (`#FF0000`…) fall back to the
  component colour. Headsigns like `Andalucía || Portal Norte` render as
  `Andalucía → Portal Norte`.
- **Ubica tu bus** — station → route chips → next buses labelled **En vivo /
  Por programación / Estimado**, stops away and distance, with the route's
  buses drawn on a map tinted by ETA bucket (≤5 · ≤10 · ≤15 min).
- **Arrival board** on every stop — grouped by route, two lines per route:
  headsign + the big first ETA on the right, then "luego 5 · 7 min" with a
  live dot only on realtime numbers; the component is the header subtitle
  ("Estación troncal"). Originally: "Siguiente en 5 min ·
  luego 10, 15 y 20", live/scheduled badge per time, auto-refresh from the
  city's `config.departuresRefreshSeconds`. Works against older APIs too (the
  client groups the flat departures list itself).
- **Freshness everywhere** — "En vivo" · "Programado" · "Sin datos en vivo
  hace N s", from `/health` and per-response `freshness`.
- **Live buses** coloured by component, culled to the viewport and
  **interpolated** between SSE frames (10 Hz ticker, eased) so they glide
  instead of jumping.
- **Service hours** — "Fuera de horario · próximo 04:30" on routes, boards and
  favorites, from `RouteRef.serviceWindow`.
- **Tarifa estimada** — the API's fare, or a client estimate from
  `city.fares` (base, transfer, window, max transfers) with a breakdown;
  always marked as estimated.
- **Sorting chips** — Más rápido · Menos transbordos · Menos caminata · Más
  económico · Salida más próxima.
- **Component icons & colours** from `city.components[]` (Troncal, Alimentador,
  Dual, Zonal, TransMiCable…), no hard-coded palette.
- **Typed favorites** — Casa / Trabajo / custom icon; stops show their live
  board and routes their service hours right on the favorites screen; the last
  10 trips are kept for one-tap replanning.
- **Remote config** — forced-update and maintenance screens
  (`config.minAppVersion`, `config.maintenance`), feature flags that hide
  modules, poll intervals.
- **Deep links** — custom scheme plus **App Links / Universal Links** for the
  canonical `https://<web-host>/{city}/...` URLs; sharing emits those URLs.
- **Iniciar viaje** — follow-along mode: current leg highlighted, progress,
  and a local "Próxima parada es la tuya" notification when you are within
  ~300 m of your alighting stop (foreground location only, no backend).
- **Station services layer** — bike parking, toilets, ATMs, health points and
  libraries from `/pois` (OSM), toggleable on the map.
- **Honest accessibility** — the feed's blanket "accessible" flag is shown as
  *no verificado* with its source; real verification comes from the API.
- **Nearby-first search**, **Llegar en bici a la estación** (BICYCLE + TRANSIT)
  and **PQRS hand-off** links (never an in-app reporter).

Plus everything from v1: city picker, map with nearby stops, planner with
geocode autocomplete and my-location, itinerary detail with coloured legs and
walking steps, route detail with live buses, vehicle detail, alerts, settings
(city, es/en, theme, accessibility, walking distance), offline-safe error
states.

## Quickstart

```bash
flutter pub get
flutter gen-l10n                       # generates lib/l10n/generated

# Demo mode with bundled fixtures (no backend needed)
flutter run --dart-define=MOCK=true

# Against a local opentransit-api
flutter run --dart-define=API_URL=http://localhost:8001        # iOS simulator
flutter run --dart-define=API_URL=http://10.0.2.2:8001         # Android emulator
```

Without `API_URL` the app defaults to `http://localhost:8001` on iOS and
`http://10.0.2.2:8001` on Android.

### `--dart-define` options

| define | default | purpose |
|---|---|---|
| `MOCK` | `false` | use `assets/fixtures/*.json` instead of the network |
| `API_URL` | platform default above | base URL of opentransit-api |
| `WEB_HOST` | `opentransit.example.org` | host of the web app whose `https://` URLs this app claims and shares |
| `MAP_STYLE` | `https://tiles.openfreemap.org/styles/liberty` | MapLibre style (light) |
| `MAP_STYLE_DARK` | `https://tiles.openfreemap.org/styles/dark` | MapLibre style (dark) |

### Verify

```bash
flutter analyze --fatal-infos
flutter test                                         # 104 unit + widget tests (incl. test/rental_test.dart)
tool/screenshots.sh                                  # iOS simulator walkthrough (mock) → docs/screenshots/
tool/screenshots.sh "" integration_test/forced_update_test.dart   # forced-update screen
tool/screenshots.sh "" integration_test/live_api_test.dart \
  --dart-define=API_URL=http://localhost:8001        # same, against a running API
```

## Mock mode

`MockApiClient` implements the same `ApiClient` interface as the HTTP client and
serves the JSON under `assets/fixtures/` (Bogotá + a Medellín stub, three
itineraries Portal Norte → Portal Sur with estimated fares, stops with boards,
next buses, ~30 vehicles that move along their routes every 4 s, alerts, POIs,
geocode results, health). Timestamps are shifted so they are always "around
now". Regenerate with `python3 tool/gen_fixtures.py` if you change the shapes.

## Project layout

```
lib/
  main.dart, app.dart, router.dart          bootstrap, MaterialApp.router (+ ConfigGate), routes
  core/
    config.dart                             dart-defines (API_URL, MOCK, WEB_HOST, map styles)
    api/       api_client.dart (interface) · http_api_client.dart (dio, v1.1 fallbacks) · mock_api_client.dart · sse.dart
    models/    city (components, fares, config, links, services) · plan · transit (serviceWindow, accessibility) · live (board, next, pois, health) · vehicle
    live/      interpolation.dart            eased vehicle interpolation between frames
    providers.dart                          Riverpod: settings, cities, health, favorites, recents, alert impressions, boards, next buses, pois, live stream
    storage/   preferences · favorites (typed favorites, recent trips, alert impressions)
    theme/     app_theme.dart               Material 3 seeded from the city colour
    utils/     fare · service_window · eta · version · links (canonical https) · notifications · polyline · geo · colors · format · location
    widgets/   transit_map.dart (MapLibre + GeoJSON overlays incl. POIs) · common.dart (RouteChip, ComponentBadge, FreshnessLabel, ServiceHint, FareText…)
  features/
    rental/                                 station sheet (availability, "Cómo llegar", app hand-off)
    home/ (hub tiles, alert carousel) · locate/ (Ubica tu bus) · planner/ (plan, results + sorting, itinerary + fare, follow-along)
    stops/ (board) · routes/ (list, detail) · live/ · alerts/ · favorites/ (typed, save sheet) · settings/ · config/ (gate) · cities/
  l10n/       app_es.arb (source) · app_en.arb · generated/
assets/fixtures/                            mock data
integration_test/                           screenshots_test · forced_update_test · live_api_test (cues for tool/screenshots.sh)
test/                                       unit + widget tests
```

## API contract

The app consumes `opentransit-api` v1/v1.1 (`/v1/cities/{city}/…`). Ids for
stops, routes and trips are opaque, feed-scoped strings (`bogota:1234`). Times
are ISO-8601 with offset and are displayed in the device's local time. The
Dart models in `lib/core/models/` mirror the contract field by field; every
v1.1 field is optional so the app keeps working against a v1 API (boards are
grouped client-side, fares estimated from city parameters when present).

## Adding a city

Nothing changes in this repo. When `opentransit-api` lists a new city in
`GET /v1/cities`, it shows up in the picker with its own colour, modes,
bounding box, component palette, fare parameters, feature flags, links and
partner tiles. Screens hide what a city does not support.

### Shared bikes (v1.2)

Bike-share is **per-city configuration, N networks per city**, never a
hardcoded provider. The app reads `city.features.bikeShare`,
`city.config.features.bikeShare` and `city.mobility.bikeShare[]`
(`id, name, network, gbfsUrl, color, url, apps{ios,android}, pricingSummary,
formFactors`) and uses the network's own `name`, `color` and links everywhere:
the planner chip ("Bici pública", or the network names when a city has
several), rental legs (`leg.rental` with `pickup`/`dropoff` stations and a
`priceEstimate`), the "Bicis públicas" map layer (`/rental/stations?bbox=`,
refreshed on the feed's TTL), the station sheet ("Cómo llegar" · "Abrir
{name}") and the nearest-station card in "Cerca de ti"
(`/stops/nearby?include=rental`). Fares add one pass per network from the leg's
price estimate. Requesting shared bikes adds `BIKE_RENTAL` (and
`SCOOTER_RENTAL` when a network lists scooters) to the plan `modes`.
The Medellín fixture ships two networks to keep the UI honest about N.

## Deep links

Custom scheme:
`opentransit://{city}/plan?fromLat=4.75&fromLon=-74.04&toLat=4.59&toLon=-74.16&fromName=Portal%20Norte&toName=Portal%20Sur[&time=ISO][&arriveBy=true]`,
`opentransit://{city}/stops/{stopId}`, `.../routes/{routeId}`, `.../locate?stop=&route=`, `.../alerts`.

Canonical web URLs (`https://<WEB_HOST>/{city}/...`) open in the app too. The
placeholder host `opentransit.example.org` lives in
`android/app/src/main/AndroidManifest.xml` (App Links intent filter) and
`ios/Runner/Runner.entitlements` (associated domains); replace it with the
deployed web host, keep the `WEB_HOST` dart-define in sync, and publish
`/.well-known/assetlinks.json` and `apple-app-site-association` on that host.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Data attribution for Bogotá:
TRANSMILENIO S.A. (GTFS / GTFS-RT). Map: © OpenMapTiles © OpenStreetMap
contributors, tiles by OpenFreeMap. POIs: © OpenStreetMap contributors.
