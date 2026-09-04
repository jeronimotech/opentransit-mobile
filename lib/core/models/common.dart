/// Small helpers shared by all hand-written `fromJson` constructors.
library;

DateTime? parseTime(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}

int? asInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.round();
  return int.tryParse(v.toString());
}

double? asDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

bool asBool(Object? v, {bool fallback = false}) {
  if (v is bool) return v;
  if (v is String) return v.toLowerCase() == 'true';
  return fallback;
}

List<T> asList<T>(Object? v, T Function(Map<String, dynamic>) f) {
  if (v is! List) return const [];
  return v
      .whereType<Map>()
      .map((e) => f(Map<String, dynamic>.from(e)))
      .toList(growable: false);
}

List<String> asStrings(Object? v) =>
    v is List ? v.map((e) => e.toString()).toList(growable: false) : const [];

/// Transit component (a city-specific grouping of agencies).
enum Component {
  trunk,
  feeder,
  dual,
  zonal,
  cable,
  rail,
  other;

  static Component? parse(Object? v) {
    if (v == null) return null;
    final s = v.toString();
    for (final c in values) {
      if (c.name == s) return c;
    }
    return Component.other;
  }
}

/// Travel mode as used by the API (and OTP).
enum TravelMode {
  walk('WALK'),
  bus('BUS'),
  rail('RAIL'),
  subway('SUBWAY'),
  tram('TRAM'),
  cableCar('CABLE_CAR'),
  bicycle('BICYCLE'),
  car('CAR'),
  ferry('FERRY'),
  transit('TRANSIT');

  const TravelMode(this.wire);
  final String wire;

  static TravelMode parse(Object? v) {
    final s = v?.toString().toUpperCase() ?? '';
    for (final m in values) {
      if (m.wire == s) return m;
    }
    return TravelMode.bus;
  }

  bool get isTransit => this != walk && this != bicycle && this != car;
}

class LatLng {
  const LatLng(this.lat, this.lon);
  final double lat;
  final double lon;

  factory LatLng.fromJson(Map<String, dynamic> j) =>
      LatLng(asDouble(j['lat']) ?? 0, asDouble(j['lon']) ?? 0);

  @override
  bool operator ==(Object other) =>
      other is LatLng && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(lat, lon);

  @override
  String toString() =>
      '${lat.toStringAsFixed(5)},${lon.toStringAsFixed(5)}';
}

class Geometry {
  const Geometry({required this.encoded, this.precision = 5});
  final String encoded;
  final int precision;

  factory Geometry.fromJson(Map<String, dynamic> j) => Geometry(
        encoded: j['encoded']?.toString() ?? '',
        precision: asInt(j['precision']) ?? 5,
      );
}
