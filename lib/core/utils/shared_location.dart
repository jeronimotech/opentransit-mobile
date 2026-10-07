import '../models/models.dart';

/// A place that arrived from outside the app: a `geo:` URI, or text someone shared to us.
///
/// Either a point, or a search phrase when the sender gave a name and no coordinates — Google Maps
/// sends `geo:0,0?q=Museo del Oro` for a place it has not resolved, and our own place search is a
/// better answer to that than silence. Exactly one of [position] and [query] is set.
class SharedLocation {
  const SharedLocation._({this.position, this.name, this.query});

  const SharedLocation.at(LatLng position, {String? name})
      : this._(position: position, name: name);

  const SharedLocation.search(String query) : this._(query: query);

  final LatLng? position;

  /// The label the sender attached, when there was one. Worth keeping: "Museo del Oro" in the
  /// destination field tells the rider the share worked; "4.6010, -74.0718" makes them check.
  final String? name;

  /// A phrase to hand to place search, when no coordinates came through.
  final String? query;

  bool get isPoint => position != null;
}

/// RFC 5870 `geo:` plus the map-link and plain-text shapes other apps actually share.
///
/// Deliberately offline. `maps.app.goo.gl` and other shortlinks resolve only by following an HTTP
/// redirect, so they return null here rather than pretending: a wrong pin is worse than telling
/// someone the link could not be read. Nothing in this file performs a network request or a
/// geocode — it reads what the sender already said.
SharedLocation? parseSharedLocation(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  // A URI handed over by the OS arrives whole, spaces included: `geo:0,0?q=Museo del Oro` is one
  // intent, not a sentence with a link in it. Try the whole string as a URI before going hunting
  // inside it, or the hunt stops at the first space and truncates the name.
  final whole = Uri.tryParse(text);
  if (whole != null && _isLocationScheme(whole.scheme)) return _fromUri(whole);

  // Otherwise it is shared text, usually a sentence with a link in it ("Meet me here https://…").
  final found = _firstUri(text);
  if (found != null) return _fromUri(found);

  // No link at all: the whole thing may be a pasted coordinate pair.
  return _bareCoordinates(text);
}

bool _isLocationScheme(String scheme) =>
    const {'geo', 'http', 'https'}.contains(scheme.toLowerCase());

SharedLocation? _fromUri(Uri uri) => switch (uri.scheme.toLowerCase()) {
      'geo' => _fromGeo(uri),
      // A link that is not a readable map link reads as nothing. Mining a news article's path for
      // two comma-separated numbers is how a share of someone's blog post becomes a pin.
      'http' || 'https' => _fromWebMapLink(uri),
      _ => null,
    };

/// `geo:4.65,-74.08`, `geo:4.65,-74.08?z=17`, `geo:0,0?q=4.65,-74.08(Museo del Oro)`,
/// `geo:0,0?q=Museo del Oro`.
SharedLocation? _fromGeo(Uri uri) {
  // An opaque URI keeps the body in `path`; `queryParameters` still parses the part after `?`.
  final body = uri.path;
  final q = uri.queryParameters['q'];

  // `0,0` is the placeholder Google Maps uses when the real answer is in `q`, so it is not a point
  // off the coast of Ghana — it is "look in q". A genuine share of the null island is a loss we
  // accept, and it has no transit.
  final atBody = _coordinates(body);
  if (atBody != null && !(atBody.lat == 0 && atBody.lon == 0)) {
    return SharedLocation.at(atBody, name: _nameFrom(q));
  }
  if (q == null || q.trim().isEmpty) return null;

  final atQuery = _coordinates(q);
  if (atQuery != null) return SharedLocation.at(atQuery, name: _nameFrom(q));

  // A name with no coordinates. Our place search can do something with that.
  return SharedLocation.search(q.trim());
}

/// Google Maps, Apple Maps and OpenStreetMap links that carry coordinates in plain sight.
SharedLocation? _fromWebMapLink(Uri uri) {
  final host = uri.host.toLowerCase();
  final isMap = host.contains('google.') && uri.path.contains('/maps') ||
      host.startsWith('maps.') ||
      host.endsWith('openstreetmap.org') ||
      host == 'osm.org';
  if (!isMap) return null;

  // `/maps/place/Museo+del+Oro/@4.6010,-74.0718,17z/…` — the @ pair is the viewport centre, which
  // for a /place/ link is the place.
  final at = RegExp(r'@(-?\d+\.?\d*),(-?\d+\.?\d*)').firstMatch(uri.path);
  if (at != null) {
    final p = _latLng(at.group(1), at.group(2));
    if (p != null) return SharedLocation.at(p, name: _placeNameFromPath(uri.path));
  }

  // `?q=`, `?ll=`, `?daddr=`, `?query=`, `?destination=` all carry a pair in one form or another.
  for (final key in ['q', 'll', 'daddr', 'query', 'destination', 'sll', 'center']) {
    final v = uri.queryParameters[key];
    if (v == null) continue;
    final p = _coordinates(v);
    if (p != null) return SharedLocation.at(p, name: _nameFrom(uri.queryParameters['q']));
  }

  // OpenStreetMap puts it in the fragment: `#map=17/4.6010/-74.0718`.
  final frag = RegExp(r'map=\d+\.?\d*/(-?\d+\.?\d*)/(-?\d+\.?\d*)').firstMatch(uri.fragment);
  if (frag != null) {
    final p = _latLng(frag.group(1), frag.group(2));
    if (p != null) return SharedLocation.at(p);
  }

  // A shortlink, or a search by name. Either way there is nothing here to read without the network.
  return null;
}

SharedLocation? _bareCoordinates(String text) {
  final p = _coordinates(text);
  return p == null ? null : SharedLocation.at(p);
}

/// The first `lat,lon` pair in a string, ignoring anything around it.
LatLng? _coordinates(String s) {
  final m = RegExp(r'(-?\d{1,3}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)').firstMatch(s);
  return m == null ? null : _latLng(m.group(1), m.group(2));
}

LatLng? _latLng(String? lat, String? lon) {
  final a = double.tryParse(lat ?? '');
  final o = double.tryParse(lon ?? '');
  // Out-of-range numbers are not a coordinate pair that happened to be mangled — they are some
  // other pair of numbers, a price range or a date, and guessing would drop a pin in the sea.
  if (a == null || o == null || a < -90 || a > 90 || o < -180 || o > 180) return null;
  return LatLng(a, o);
}

/// `4.60,-74.07(Museo del Oro)` -> `Museo del Oro`; a bare name stays itself; coordinates alone
/// have no name.
String? _nameFrom(String? q) {
  if (q == null) return null;
  final paren = RegExp(r'\(([^)]+)\)').firstMatch(q);
  if (paren != null) return paren.group(1)!.trim();
  return _coordinates(q) != null ? null : (q.trim().isEmpty ? null : q.trim());
}

/// `/maps/place/Museo+del+Oro/@…` -> `Museo del Oro`.
String? _placeNameFromPath(String path) {
  final m = RegExp(r'/place/([^/@]+)').firstMatch(path);
  if (m == null) return null;
  final decoded = Uri.decodeComponent(m.group(1)!).replaceAll('+', ' ').trim();
  return decoded.isEmpty ? null : decoded;
}

/// The first http(s) or geo URI inside a block of shared text.
Uri? _firstUri(String text) {
  final m = RegExp(r'(?:https?://|geo:)\S+').firstMatch(text);
  if (m == null) return null;
  // Shared text often ends a sentence right after the link.
  final cleaned = m.group(0)!.replaceAll(RegExp(r'[.,;)\]]+$'), '');
  return Uri.tryParse(cleaned);
}
