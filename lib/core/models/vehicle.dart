import 'common.dart';
import 'transit.dart';

class Vehicle {
  const Vehicle({
    required this.id,
    this.label,
    this.routeId,
    this.routeShortName,
    this.tripId,
    this.tripResolved = false,
    this.component,
    required this.position,
    this.bearing,
    this.timestamp,
    this.stopId,
    this.stopSequence,
    this.occupancy,
  });
  final String id;
  final String? label;
  final String? routeId;
  final String? routeShortName;
  final String? tripId;
  final bool tripResolved;
  final Component? component;
  final LatLng position;
  final double? bearing;
  final DateTime? timestamp;
  final String? stopId;
  final int? stopSequence;
  final String? occupancy;

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
        id: j['id'].toString(),
        label: j['label']?.toString(),
        routeId: j['routeId']?.toString(),
        routeShortName: j['routeShortName']?.toString(),
        tripId: j['tripId']?.toString(),
        tripResolved: asBool(j['tripResolved']),
        component: Component.parse(j['component']),
        position: LatLng.fromJson(j),
        bearing: asDouble(j['bearing']),
        timestamp: parseTime(j['timestamp']),
        stopId: j['stopId']?.toString(),
        stopSequence: asInt(j['stopSequence']),
        occupancy: j['occupancy']?.toString(),
      );

  /// Applies a partial (delta) update: any key present in [j] overrides.
  Vehicle merge(Map<String, dynamic> j) => Vehicle(
        id: id,
        label: j.containsKey('label') ? j['label']?.toString() : label,
        routeId: j.containsKey('routeId') ? j['routeId']?.toString() : routeId,
        routeShortName: j.containsKey('routeShortName')
            ? j['routeShortName']?.toString()
            : routeShortName,
        tripId: j.containsKey('tripId') ? j['tripId']?.toString() : tripId,
        tripResolved: j.containsKey('tripResolved')
            ? asBool(j['tripResolved'])
            : tripResolved,
        component: j.containsKey('component')
            ? Component.parse(j['component'])
            : component,
        position: LatLng(
          asDouble(j['lat']) ?? position.lat,
          asDouble(j['lon']) ?? position.lon,
        ),
        bearing: j.containsKey('bearing') ? asDouble(j['bearing']) : bearing,
        timestamp:
            j.containsKey('timestamp') ? parseTime(j['timestamp']) : timestamp,
        stopId: j.containsKey('stopId') ? j['stopId']?.toString() : stopId,
        stopSequence: j.containsKey('stopSequence')
            ? asInt(j['stopSequence'])
            : stopSequence,
        occupancy:
            j.containsKey('occupancy') ? j['occupancy']?.toString() : occupancy,
      );
}

class VehicleHealth {
  const VehicleHealth({
    this.entityAgeP50Seconds,
    this.pctTripResolved,
    this.httpStatus,
  });
  final int? entityAgeP50Seconds;
  final double? pctTripResolved;
  final int? httpStatus;

  factory VehicleHealth.fromJson(Map<String, dynamic>? j) => j == null
      ? const VehicleHealth()
      : VehicleHealth(
          entityAgeP50Seconds: asInt(j['entityAgeP50Seconds']),
          pctTripResolved: asDouble(j['pctTripResolved']),
          httpStatus: asInt(j['httpStatus']),
        );
}

/// A full snapshot of the live fleet, as held by the client.
class VehicleFrame {
  const VehicleFrame({
    required this.seq,
    required this.generatedAt,
    this.feedTimestamp,
    required this.health,
    required this.vehicles,
  });
  final int seq;
  final DateTime generatedAt;
  final DateTime? feedTimestamp;
  final VehicleHealth health;
  final Map<String, Vehicle> vehicles;

  int get count => vehicles.length;

  factory VehicleFrame.fromJson(Map<String, dynamic> j) {
    final list = asList(j['vehicles'], Vehicle.fromJson);
    return VehicleFrame(
      seq: asInt(j['seq']) ?? 0,
      generatedAt: parseTime(j['generatedAt']) ?? DateTime.now(),
      feedTimestamp: parseTime(j['feedTimestamp']),
      health: VehicleHealth.fromJson(
        j['health'] is Map
            ? Map<String, dynamic>.from(j['health'] as Map)
            : null,
      ),
      vehicles: {for (final v in list) v.id: v},
    );
  }

  /// Applies one SSE event. A `full` event replaces the frame; a `delta`
  /// event merges `updated` and drops `removed`.
  VehicleFrame apply(Map<String, dynamic> event) {
    final type = event['type']?.toString() ?? 'full';
    if (type == 'full') return VehicleFrame.fromJson(event);
    final next = Map<String, Vehicle>.from(vehicles);
    for (final raw in (event['updated'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final j = Map<String, dynamic>.from(raw);
      final id = j['id']?.toString();
      if (id == null) continue;
      final existing = next[id];
      next[id] = existing == null ? Vehicle.fromJson(j) : existing.merge(j);
    }
    for (final id in asStrings(event['removed'])) {
      next.remove(id);
    }
    return VehicleFrame(
      seq: asInt(event['seq']) ?? seq + 1,
      generatedAt: parseTime(event['generatedAt']) ?? DateTime.now(),
      feedTimestamp: parseTime(event['feedTimestamp']) ?? feedTimestamp,
      health: event['health'] is Map
          ? VehicleHealth.fromJson(
              Map<String, dynamic>.from(event['health'] as Map))
          : health,
      vehicles: next,
    );
  }
}

class VehicleDetail {
  const VehicleDetail({
    required this.vehicle,
    this.route,
    this.tripHeadsign,
    this.shape,
    this.currentStop,
    this.nextStop,
    this.etaSeconds,
    this.delaySeconds,
    this.historyPoints = const [],
    this.avgKmh,
    this.alerts = const [],
  });
  final Vehicle vehicle;
  final RouteRef? route;
  final String? tripHeadsign;
  final Geometry? shape;
  final Stop? currentStop;
  final Stop? nextStop;
  final int? etaSeconds;
  final int? delaySeconds;
  final List<LatLng> historyPoints;
  final double? avgKmh;
  final List<TransitAlert> alerts;

  factory VehicleDetail.fromJson(Map<String, dynamic> j) {
    final trip = j['trip'] is Map
        ? Map<String, dynamic>.from(j['trip'] as Map)
        : const <String, dynamic>{};
    final history = j['history'] is Map
        ? Map<String, dynamic>.from(j['history'] as Map)
        : const <String, dynamic>{};
    return VehicleDetail(
      vehicle: Vehicle.fromJson(j),
      route: j['route'] is Map
          ? RouteRef.fromJson(Map<String, dynamic>.from(j['route'] as Map))
          : null,
      tripHeadsign: trip['headsign']?.toString(),
      shape: j['shape'] is Map
          ? Geometry.fromJson(Map<String, dynamic>.from(j['shape'] as Map))
          : null,
      currentStop: j['currentStop'] is Map
          ? Stop.fromJson(Map<String, dynamic>.from(j['currentStop'] as Map))
          : null,
      nextStop: j['nextStop'] is Map
          ? Stop.fromJson(Map<String, dynamic>.from(j['nextStop'] as Map))
          : null,
      etaSeconds: asInt(j['etaSeconds']),
      delaySeconds: asInt(j['delaySeconds']),
      historyPoints: (history['points'] as List? ?? const [])
          .whereType<List>()
          .where((p) => p.length >= 2)
          .map((p) => LatLng(asDouble(p[1]) ?? 0, asDouble(p[0]) ?? 0))
          .toList(growable: false),
      avgKmh: asDouble(history['avgKmh']),
      alerts: asList(j['alerts'], TransitAlert.fromJson),
    );
  }
}
