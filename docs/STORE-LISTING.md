# Store listing copy

Draft text for App Store Connect and Play Console, Spanish first because Bogotá is the
launch city. Nothing here promises a feature the app does not have; check it against the
build before publishing, and cut anything that has since changed.

Support and marketing URLs, both live:

- Marketing / project: `https://opentransit.tech`
- Support: `https://bogota.opentransit.tech/bogota`
- Privacy: `https://bogota.opentransit.tech/bogota/privacy`

---

## App Store

**Name** (30 chars max)

```
opentransit Bogotá
```

**Subtitle** (30 chars max)

```
TransMilenio y SITP en vivo
```

*Counted: 27 of 30. App Store Connect truncates silently, so count any edit before pasting.*

**Promotional text** (170 chars, editable without review — use it for service news)

```
Buses en tiempo real, rutas puerta a puerta y tu bus ubicado en el mapa. Datos abiertos de TransMilenio, sin cuentas y sin publicidad.
```

**Keywords** (100 chars total, comma separated, no spaces after commas, do not repeat the
app name or the subtitle — Apple already indexes those)

```
transmilenio,sitp,bogota,buses,rutas,transporte,publico,tiempo real,bicicleta,tullave
```

**Description**

```
opentransit planea tu viaje por Bogotá con datos abiertos y en tiempo real.

PLANEA PUERTA A PUERTA
Escribe una dirección, un lugar o una estación, o elige el punto directamente en el mapa. Combina caminata, TransMilenio, SITP, cable y bicicleta compartida en un solo viaje.

BUSES EN TIEMPO REAL
Mira dónde va tu bus mientras esperas. La app te dice si el dato está fresco y nunca muestra como "en vivo" algo que no lo está.

CERCA DE MÍ
Un mapa centrado en ti con los buses que se mueven a tu alrededor, ordenados por distancia y con la dirección en la que van.

UBICA TU BUS
Elige ruta y parada y sigue el vehículo que viene, en el mapa.

TU VIAJE, COMPARTIDO
Manda un enlace a quien te espera. Ve el trayecto y el avance, caduca solo y lo puedes revocar.

SIN CUENTAS, SIN PUBLICIDAD
No pedimos registro ni correo. No hay anuncios ni rastreadores, y la analítica es anónima y se puede apagar en Ajustes.

CÓDIGO ABIERTO
Todo el código es público. Lo que dice nuestra política de privacidad se puede verificar leyéndolo: github.com/jeronimotech

Datos: TRANSMILENIO S.A. (GTFS y GTFS-Realtime). Mapa: © OpenStreetMap.
```

**What's New** (first release)

```
Primera versión pública.
```

---

## Google Play

**App name** (30 chars)

```
opentransit Bogotá
```

**Short description** (80 chars)

```
Rutas puerta a puerta y buses en tiempo real con datos abiertos de Bogotá.
```

**Full description** (4000 chars) — the App Store description above works as-is. Play
renders line breaks, so keep the section headings.

---

## English

Used for the `en-US` locale in both stores.

**Subtitle / short description**

```
Live buses, door to door
```

**Description** — same structure:

```
opentransit plans your trip across Bogotá on open, real-time data.

DOOR TO DOOR
Type an address, a place or a station, or pick the point straight off the map. It combines walking, TransMilenio, SITP, cable car and bike share into one trip.

BUSES IN REAL TIME
See where your bus is while you wait. The app tells you how fresh the data is, and never shows something as "live" when it isn't.

NEARBY
A map centred on you with the buses moving around you, sorted by distance, showing which way they are heading.

FIND YOUR BUS
Pick a route and a stop and follow the vehicle that is coming, on the map.

SHARE YOUR TRIP
Send a link to whoever is waiting. They see the route and its progress; it expires on its own and you can revoke it.

NO ACCOUNTS, NO ADS
No sign-up, no email. No advertising and no trackers, and the anonymous analytics can be switched off in Settings.

OPEN SOURCE
All the code is public. Everything our privacy policy claims can be verified by reading it: github.com/jeronimotech

Data: TRANSMILENIO S.A. (GTFS and GTFS-Realtime). Map: © OpenStreetMap.
```

---

## Before you submit

- **Category:** Navigation (Apple) / Maps & Navigation (Play).
- **Screenshots:** see `docs/store/`.
- **Privacy answers:** see `docs/STORE-PRIVACY.md`. They change if the assistant is
  switched on.
- **Reviewer notes:** say the app needs no account and works anywhere, but that transit
  data covers Bogotá — a reviewer testing from another city will otherwise see an empty
  map and may reject it as broken. Give them a coordinate to try.
