import 'common.dart';
import 'rental.dart';
import 'transit.dart';
import 'vehicle.dart';

/// How fresh the realtime data behind a response is.
class Freshness {
  const Freshness({this.realtime = false, this.ageSeconds, this.stale = false});
  final bool realtime;
  final int? ageSeconds;
  final bool stale;

  factory Freshness.fromJson(Map<String, dynamic>? j) => j == null
      ? const Freshness()
      : Freshness(
          realtime: asBool(j['realtime']),
          ageSeconds: asInt(j['ageSeconds']),
          stale: asBool(j['stale']),
        );
}

/// One upcoming time inside a board row.
class BoardTime {
  const BoardTime({
    required this.time,
    required this.minutes,
    required this.realtime,
    this.delaySeconds,
    this.tripId,
    this.vehicleId,
  });
  final DateTime time;
  final int minutes;
  final bool realtime;
  final int? delaySeconds;
  final String? tripId;
  final String? vehicleId;

  factory BoardTime.fromJson(Map<String, dynamic> j, {DateTime? now}) {
    final t = parseTime(j['time']) ?? DateTime.now();
    return BoardTime(
      time: t,
      minutes: asInt(j['minutes']) ??
          (t.difference(now ?? DateTime.now()).inSeconds / 60).round(),
      realtime: asBool(j['realtime']),
      delaySeconds: asInt(j['delaySeconds']),
      tripId: j['tripId']?.toString(),
      vehicleId: j['vehicleId']?.toString(),
    );
  }
}

/// Arrival board row: one route (+ headsign) with its next N times.
class BoardRow {
  const BoardRow({required this.route, this.headsign, required this.next});
  final RouteRef route;
  final String? headsign;
  final List<BoardTime> next;

  factory BoardRow.fromJson(Map<String, dynamic> j) => BoardRow(
        route: RouteRef.fromJson(Map<String, dynamic>.from(j['route'] as Map)),
        headsign: j['headsign']?.toString(),
        next: (j['next'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => BoardTime.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
      );
}

class BoardResponse {
  const BoardResponse({
    required this.stop,
    required this.generatedAt,
    this.freshness = const Freshness(),
    required this.rows,
  });
  final Stop stop;
  final DateTime generatedAt;
  final Freshness freshness;
  final List<BoardRow> rows;

  factory BoardResponse.fromJson(Map<String, dynamic> j) => BoardResponse(
        stop: Stop.fromJson(Map<String, dynamic>.from(j['stop'] as Map)),
        generatedAt: parseTime(j['generatedAt']) ?? DateTime.now(),
        freshness: Freshness.fromJson(
          j['freshness'] is Map
              ? Map<String, dynamic>.from(j['freshness'] as Map)
              : null,
        ),
        rows: asList(j['rows'], BoardRow.fromJson),
      );

  /// Client-side fallback: groups a flat departures list by route + headsign,
  /// keeps the first [perRoute] times of each group and sorts rows by their
  /// first time. Used when the API predates `/board`.
  factory BoardResponse.fromDepartures(DeparturesResponse d,
      {int perRoute = 3, DateTime? now}) {
    final at = now ?? DateTime.now();
    final groups = <String, List<Departure>>{};
    final order = <String>[];
    for (final dep in d.departures) {
      if (dep.canceled) continue;
      final key = '${dep.route.id}|${dep.headsign ?? ''}';
      if (!groups.containsKey(key)) order.add(key);
      (groups[key] ??= []).add(dep);
    }
    final rows = <BoardRow>[];
    for (final key in order) {
      final deps = groups[key]!..sort((a, b) => a.effectiveTime.compareTo(b.effectiveTime));
      rows.add(BoardRow(
        route: deps.first.route,
        headsign: deps.first.headsign,
        next: [
          for (final dep in deps.take(perRoute))
            BoardTime(
              time: dep.effectiveTime,
              minutes: (dep.effectiveTime.difference(at).inSeconds / 60).round(),
              realtime: dep.realtime,
              delaySeconds: dep.delaySeconds,
              tripId: dep.tripId,
              vehicleId: dep.vehicleId,
            ),
        ],
      ));
    }
    rows.sort((a, b) {
      if (a.next.isEmpty || b.next.isEmpty) return a.next.length - b.next.length;
      return a.next.first.time.compareTo(b.next.first.time);
    });
    final anyRt = d.departures.any((x) => x.realtime);
    return BoardResponse(
      stop: d.stop,
      generatedAt: d.generatedAt,
      freshness: Freshness(realtime: anyRt),
      rows: rows,
    );
  }
}

/// One upcoming bus for a stop + route ("Ubica tu bus").
class NextBus {
  const NextBus({
    required this.minutes,
    required this.time,
    required this.source,
    this.vehicle,
    this.stopsAway,
    this.distanceMeters,
    this.tripId,
  });
  final int minutes;
  final DateTime time;

  /// `live | estimated | scheduled`
  final String source;
  final Vehicle? vehicle;
  final int? stopsAway;
  final int? distanceMeters;
  final String? tripId;

  bool get isLive => source == 'live';
  bool get isEstimated => source == 'estimated';

  factory NextBus.fromJson(Map<String, dynamic> j, {DateTime? now}) {
    final t = parseTime(j['time']) ?? DateTime.now();
    return NextBus(
      minutes: asInt(j['minutes']) ??
          (t.difference(now ?? DateTime.now()).inSeconds / 60).round(),
      time: t,
      source: j['source']?.toString() ?? 'scheduled',
      vehicle: j['vehicle'] is Map
          ? Vehicle.fromJson(Map<String, dynamic>.from(j['vehicle'] as Map))
          : null,
      stopsAway: asInt(j['stopsAway']),
      distanceMeters: asInt(j['distanceMeters']),
      tripId: j['tripId']?.toString(),
    );
  }
}

class NextBusesResponse {
  const NextBusesResponse({
    required this.stop,
    required this.route,
    this.freshness = const Freshness(),
    required this.next,
  });
  final Stop stop;
  final RouteRef route;
  final Freshness freshness;
  final List<NextBus> next;

  factory NextBusesResponse.fromJson(Map<String, dynamic> j) =>
      NextBusesResponse(
        stop: Stop.fromJson(Map<String, dynamic>.from(j['stop'] as Map)),
        route: RouteRef.fromJson(Map<String, dynamic>.from(j['route'] as Map)),
        freshness: Freshness.fromJson(
          j['freshness'] is Map
              ? Map<String, dynamic>.from(j['freshness'] as Map)
              : null,
        ),
        next: (j['next'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => NextBus.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
      );
}

/// Point of interest from the per-city GeoJSON layer.
class Poi {
  const Poi({
    required this.id,
    required this.type,
    this.name,
    required this.position,
    this.source = 'osm',
    this.wheelchair,
  });
  final String id;

  /// `bike_parking | toilets | atm | health | library | ...`
  final String type;
  final String? name;
  final LatLng position;
  final String source;
  final String? wheelchair;

  /// Parses one GeoJSON `Feature` with a `Point` geometry.
  static Poi? fromFeature(Map<String, dynamic> f) {
    final geom = f['geometry'];
    if (geom is! Map || geom['type'] != 'Point') return null;
    final coords = geom['coordinates'];
    if (coords is! List || coords.length < 2) return null;
    final props = f['properties'] is Map
        ? Map<String, dynamic>.from(f['properties'] as Map)
        : const <String, dynamic>{};
    final id = (props['id'] ?? f['id'])?.toString();
    if (id == null) return null;
    return Poi(
      id: id,
      type: props['type']?.toString() ?? 'poi',
      name: props['name']?.toString(),
      position: LatLng(asDouble(coords[1]) ?? 0, asDouble(coords[0]) ?? 0),
      source: props['source']?.toString() ?? 'osm',
      wheelchair: props['wheelchair']?.toString(),
    );
  }

  static List<Poi> fromCollection(Map<String, dynamic> fc) => [
        for (final f in (fc['features'] as List? ?? const []))
          if (f is Map) ?Poi.fromFeature(Map<String, dynamic>.from(f)),
      ];
}

/// `/v1/cities/{city}/health`, realtime part (what the UI needs).
class RealtimeHealth {
  const RealtimeHealth({
    this.enabled = true,
    this.lastFetchAt,
    this.entityAgeP50Seconds,
    this.vehicles,
    this.pctTripResolved,
    this.alerts,
    this.stale,
    this.staleSeconds,
  });
  final bool enabled;
  final DateTime? lastFetchAt;
  final int? entityAgeP50Seconds;
  final int? vehicles;
  final double? pctTripResolved;
  final int? alerts;
  final bool? stale;
  final int? staleSeconds;

  /// Stale when the API says so, else when the median entity age is > 90 s.
  bool get isStale => stale ?? ((entityAgeP50Seconds ?? 0) > 90);

  /// Seconds since live data was last known good, for "hace N s" labels.
  int? get ageSeconds => staleSeconds ?? entityAgeP50Seconds;

  factory RealtimeHealth.fromJson(Map<String, dynamic>? j) => j == null
      ? const RealtimeHealth(enabled: false)
      : RealtimeHealth(
          enabled: asBool(j['enabled'], fallback: true),
          lastFetchAt: parseTime(j['lastFetchAt']),
          entityAgeP50Seconds: asInt(j['entityAgeP50Seconds']),
          vehicles: asInt(j['vehicles']),
          pctTripResolved: asDouble(j['pctTripResolved']),
          alerts: asInt(j['alerts']),
          stale: j['stale'] is bool ? j['stale'] as bool : null,
          staleSeconds: asInt(j['staleSeconds']),
        );
}

class CityHealth {
  const CityHealth({
    this.realtime = const RealtimeHealth(enabled: false),
    this.routerUp = true,
    this.routerVersion,
    this.feedVersion,
    this.rental = const [],
  });
  final RealtimeHealth realtime;
  final bool routerUp;
  final String? routerVersion;
  final String? feedVersion;

  /// Per-network shared-bike feed health (v1.2 `health.rental.networks`).
  final List<RentalNetworkHealth> rental;

  RentalNetworkHealth? rentalOf(String id) => rental.where((n) => n.id == id).firstOrNull;

  factory CityHealth.fromJson(Map<String, dynamic> j) {
    final router = j['router'] is Map
        ? Map<String, dynamic>.from(j['router'] as Map)
        : const <String, dynamic>{};
    final st = j['static'] is Map
        ? Map<String, dynamic>.from(j['static'] as Map)
        : const <String, dynamic>{};
    final rental = j['rental'] is Map
        ? Map<String, dynamic>.from(j['rental'] as Map)
        : const <String, dynamic>{};
    return CityHealth(
      realtime: RealtimeHealth.fromJson(
        j['realtime'] is Map
            ? Map<String, dynamic>.from(j['realtime'] as Map)
            : null,
      ),
      routerUp: asBool(router['up'], fallback: true),
      routerVersion: router['version']?.toString(),
      feedVersion: st['feedVersion']?.toString(),
      rental: asList(rental['networks'], RentalNetworkHealth.fromJson),
    );
  }
}
