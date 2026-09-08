# Store privacy declarations

Answers for Apple's **App Privacy** questionnaire and Google's **Data safety** form,
with the reason for each one. Every claim was read out of the code, not remembered.

Policy URL for both stores: **https://bogota.opentransit.tech/bogota/privacy**

## What the app actually does

| Fact | Where it lives |
|---|---|
| No accounts, no sign-up, no email | there is no auth anywhere in the app |
| No advertising, analytics or crash SDK | `pubspec.yaml` — the only network-touching deps are `dio`, `geolocator`, `maplibre_gl`, `share_plus`, `url_launcher` |
| Location read only in the foreground, with permission | `geolocator`; no background location capability is declared |
| Coordinates rounded to ~110 m before an event is queued | `lib/core/analytics/analytics_event.dart` → `coarsenProps` rounds to 3 decimals |
| Session id random per launch; cohort id rotates every 30 days | `lib/core/analytics/analytics.dart` |
| Analytics opt-out in Settings, effective immediately | same file, `enabled` gate before queue and flush |
| Server keeps events 90 days, aggregates only at k ≥ 5 | `cities/bogota.yaml` → `analytics: { retention_days: 90, k_threshold: 5 }` |
| Map tiles fetched by the device from a third party | `lib/core/config.dart` → `tiles.openfreemap.org` |
| Assistant **off** in Bogotá production | `GET /v1/cities/bogota` → `config.assistant.enabled = false` |

## Apple — App Privacy

**Does the app collect data? Yes.** ("Collect" means it leaves the device, even
anonymously — being anonymous changes the *linked* and *tracking* answers, not this one.)

| Category | Collected | Linked to identity | Used for tracking | Purpose |
|---|---|---|---|---|
| Precise Location | Yes | **No** | No | App Functionality |
| Coarse Location | Yes | No | No | Analytics |
| Product Interaction (usage) | Yes | No | No | Analytics |
| Identifiers → User ID | Yes | No | No | Analytics |
| Everything else | No | — | — | — |

Notes on the two answers that are judgement calls, so you can defend them:

- **Precise Location, App Functionality.** The origin and destination of a trip reach our
  server to compute a route. It is precise by necessity, it is not stored against anyone,
  and it is never used to build a profile. Declaring it as App Functionality *and*
  separately declaring the coarsened copy under Analytics is the honest split.
- **Identifiers → User ID.** The rotating cohort id is app-generated, anonymous and
  changes every 30 days. Apple's definition of User ID is broad enough to include an
  assigned id, so declaring it is the safe reading. It is *not* a device identifier
  (no IDFA, no IDFV, and the app requests no tracking permission).

**Tracking: No.** The app does not link data to third-party data for advertising and
shows no ads, so it does not present App Tracking Transparency.

## Google — Data safety

Same substance, different vocabulary.

| Data type | Collected | Shared | Purpose | Optional? |
|---|---|---|---|---|
| Location → Approximate location | Yes | No | Analytics | Yes (Settings toggle) |
| Location → Precise location | Yes | No | App functionality | No (required to plan from where you are) |
| App activity → App interactions | Yes | No | Analytics | Yes |

- **Encrypted in transit:** Yes — every request is HTTPS.
- **You can request deletion:** there is nothing keyed to a person to delete. Say so
  plainly and point at the policy; do not claim a deletion flow that does not exist.
- **Committed to the Play Families Policy:** not applicable unless you target children.

## If you switch the assistant on

Turning it on in the city admin changes both declarations, because a typed question
leaves our servers for an external model provider:

- Apple: add **User Content → Other User Content**, collected, not linked, not tracking,
  purpose App Functionality.
- Google: add **Messages → Other in-app messages**, collected and **shared** (with the
  model provider), purpose App functionality.

The privacy page already says this by itself: it reads the city's config and names the
provider when the assistant is on. The store forms do not — they are a snapshot, so they
must be updated the same day the flag flips.

## Export compliance (Apple)

The app uses HTTPS and no custom cryptography. That is the standard exemption; answer the
encryption question accordingly and keep the app's `ITSAppUsesNonExemptEncryption` set to
`false` so the question does not reappear on every upload.

## Age rating

No user-generated content is shared between users, no ads, no gambling, no purchases.
Expect the lowest rating in both stores. The assistant, if enabled, is the only feature
that produces unpredictable text; both stores ask about that separately.
