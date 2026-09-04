import 'common.dart';
import 'transit.dart';

class Place {
  const Place({
    required this.name,
    required this.position,
    this.stopId,
    this.stopCode,
    this.arrival,
    this.departure,
    this.component,
  });
  final String name;
  final LatLng position;
  final String? stopId;
  final String? stopCode;
  final DateTime? arrival;
  final DateTime? departure;
  final Component? component;

  bool get isStop => stopId != null;

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        name: j['name']?.toString() ?? '',
        position: LatLng.fromJson(j),
        stopId: j['stopId']?.toString(),
        stopCode: j['stopCode']?.toString(),
        arrival: parseTime(j['arrival']),
        departure: parseTime(j['departure']),
        component: Component.parse(j['component']),
      );

  Place copyWith({String? name}) => Place(
        name: name ?? this.name,
        position: position,
        stopId: stopId,
        stopCode: stopCode,
        arrival: arrival,
        departure: departure,
        component: component,
      );
}

class WalkStep {
  const WalkStep({
    required this.instruction,
    required this.distanceMeters,
    required this.position,
    this.relativeDirection,
    this.streetName,
  });
  final String instruction;
  final int distanceMeters;
  final LatLng position;
  final String? relativeDirection;
  final String? streetName;

  factory WalkStep.fromJson(Map<String, dynamic> j) => WalkStep(
        instruction: j['instruction']?.toString() ?? '',
        distanceMeters: asInt(j['distanceMeters']) ?? 0,
        position: LatLng.fromJson(j),
        relativeDirection: j['relativeDirection']?.toString(),
        streetName: j['streetName']?.toString(),
      );
}

enum RealtimeState {
  scheduled,
  updated,
  canceled,
  added,
  modified;

  static RealtimeState? parse(Object? v) => switch (v?.toString()) {
        'SCHEDULED' => scheduled,
        'UPDATED' => updated,
        'CANCELED' => canceled,
        'ADDED' => added,
        'MODIFIED' => modified,
        _ => null,
      };
}

class Agency {
  const Agency({required this.id, required this.name});
  final String id;
  final String name;
  factory Agency.fromJson(Map<String, dynamic> j) =>
      Agency(id: j['id'].toString(), name: j['name']?.toString() ?? '');
}

class Leg {
  const Leg({
    required this.mode,
    required this.transit,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.from,
    required this.to,
    this.route,
    this.headsign,
    this.agency,
    this.tripId,
    required this.realtime,
    this.realtimeState,
    this.delaySeconds,
    required this.geometry,
    this.intermediateStops = const [],
    this.steps = const [],
    this.alerts = const [],
  });
  final TravelMode mode;
  final bool transit;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final int distanceMeters;
  final Place from;
  final Place to;
  final RouteRef? route;
  final String? headsign;
  final Agency? agency;
  final String? tripId;
  final bool realtime;
  final RealtimeState? realtimeState;
  final int? delaySeconds;
  final Geometry geometry;
  final List<Place> intermediateStops;
  final List<WalkStep> steps;
  final List<TransitAlert> alerts;

  factory Leg.fromJson(Map<String, dynamic> j) => Leg(
        mode: TravelMode.parse(j['mode']),
        transit: asBool(j['transit']),
        startTime: parseTime(j['startTime']) ?? DateTime.now(),
        endTime: parseTime(j['endTime']) ?? DateTime.now(),
        durationSeconds: asInt(j['durationSeconds']) ?? 0,
        distanceMeters: asInt(j['distanceMeters']) ?? 0,
        from: Place.fromJson(Map<String, dynamic>.from(j['from'] as Map)),
        to: Place.fromJson(Map<String, dynamic>.from(j['to'] as Map)),
        route: j['route'] is Map
            ? RouteRef.fromJson(Map<String, dynamic>.from(j['route'] as Map))
            : null,
        headsign: j['headsign']?.toString(),
        agency: j['agency'] is Map
            ? Agency.fromJson(Map<String, dynamic>.from(j['agency'] as Map))
            : null,
        tripId: j['tripId']?.toString(),
        realtime: asBool(j['realtime']),
        realtimeState: RealtimeState.parse(j['realtimeState']),
        delaySeconds: asInt(j['delaySeconds']),
        geometry: j['geometry'] is Map
            ? Geometry.fromJson(Map<String, dynamic>.from(j['geometry'] as Map))
            : const Geometry(encoded: ''),
        intermediateStops: asList(j['intermediateStops'], Place.fromJson),
        steps: asList(j['steps'], WalkStep.fromJson),
        alerts: asList(j['alerts'], TransitAlert.fromJson),
      );

  /// Colour for this leg: route colour for transit, null for walking.
  String? get colorHex => route?.color;
}

class Fare {
  const Fare({required this.amount, required this.currency});
  final num amount;
  final String currency;
  factory Fare.fromJson(Map<String, dynamic> j) =>
      Fare(amount: (j['amount'] as num?) ?? 0, currency: j['currency']?.toString() ?? '');
}

class Itinerary {
  const Itinerary({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.walkDistanceMeters,
    required this.walkTimeSeconds,
    required this.waitingTimeSeconds,
    required this.transfers,
    this.fare,
    this.accessible,
    required this.legs,
  });
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final int walkDistanceMeters;
  final int walkTimeSeconds;
  final int waitingTimeSeconds;
  final int transfers;
  final Fare? fare;
  final bool? accessible;
  final List<Leg> legs;

  factory Itinerary.fromJson(Map<String, dynamic> j) => Itinerary(
        id: j['id']?.toString() ?? '',
        startTime: parseTime(j['startTime']) ?? DateTime.now(),
        endTime: parseTime(j['endTime']) ?? DateTime.now(),
        durationSeconds: asInt(j['durationSeconds']) ?? 0,
        walkDistanceMeters: asInt(j['walkDistanceMeters']) ?? 0,
        walkTimeSeconds: asInt(j['walkTimeSeconds']) ?? 0,
        waitingTimeSeconds: asInt(j['waitingTimeSeconds']) ?? 0,
        transfers: asInt(j['transfers']) ?? 0,
        fare: j['fare'] is Map
            ? Fare.fromJson(Map<String, dynamic>.from(j['fare'] as Map))
            : null,
        accessible: j['accessible'] is bool ? j['accessible'] as bool : null,
        legs: asList(j['legs'], Leg.fromJson),
      );

  Iterable<Leg> get transitLegs => legs.where((l) => l.transit);
  bool get hasRealtime => legs.any((l) => l.realtime);
  List<TransitAlert> get alerts => [
        for (final l in legs) ...l.alerts,
      ];
}

class PlanResponse {
  const PlanResponse({
    required this.from,
    required this.to,
    required this.itineraries,
    this.routerEngine,
    this.routerVersion,
    this.warnings = const [],
  });
  final Place from;
  final Place to;
  final List<Itinerary> itineraries;
  final String? routerEngine;
  final String? routerVersion;
  final List<String> warnings;

  factory PlanResponse.fromJson(Map<String, dynamic> j) {
    final router = j['router'] is Map
        ? Map<String, dynamic>.from(j['router'] as Map)
        : const <String, dynamic>{};
    return PlanResponse(
      from: Place.fromJson(Map<String, dynamic>.from(j['from'] as Map)),
      to: Place.fromJson(Map<String, dynamic>.from(j['to'] as Map)),
      itineraries: asList(j['itineraries'], Itinerary.fromJson),
      routerEngine: router['engine']?.toString(),
      routerVersion: router['version']?.toString(),
      warnings: asStrings(j['warnings']),
    );
  }
}

class PlanRequest {
  const PlanRequest({
    required this.from,
    required this.to,
    this.time,
    this.arriveBy = false,
    this.modes = const [TravelMode.transit, TravelMode.walk],
    this.wheelchair = false,
    this.numItineraries = 5,
    this.maxWalkDistance = 1500,
    this.locale = 'es',
  });
  final Place from;
  final Place to;
  final DateTime? time;
  final bool arriveBy;
  final List<TravelMode> modes;
  final bool wheelchair;
  final int numItineraries;
  final int maxWalkDistance;
  final String locale;

  Map<String, String> toQuery() => {
        'fromLat': from.position.lat.toString(),
        'fromLon': from.position.lon.toString(),
        'toLat': to.position.lat.toString(),
        'toLon': to.position.lon.toString(),
        if (time != null) 'time': time!.toIso8601String(),
        'arriveBy': arriveBy.toString(),
        'modes': modes.map((m) => m.wire).join(','),
        'wheelchair': wheelchair.toString(),
        'numItineraries': numItineraries.toString(),
        'maxWalkDistance': maxWalkDistance.toString(),
        'locale': locale,
      };
}

class GeocodeResult {
  const GeocodeResult({
    required this.id,
    required this.name,
    this.label,
    required this.position,
    required this.type,
    this.stopId,
    this.component,
    required this.source,
  });
  final String id;
  final String name;
  final String? label;
  final LatLng position;

  /// `station | stop | address | poi | street`
  final String type;
  final String? stopId;
  final Component? component;
  final String source;

  factory GeocodeResult.fromJson(Map<String, dynamic> j) => GeocodeResult(
        id: j['id'].toString(),
        name: j['name']?.toString() ?? '',
        label: j['label']?.toString(),
        position: LatLng.fromJson(j),
        type: j['type']?.toString() ?? 'poi',
        stopId: j['stopId']?.toString(),
        component: Component.parse(j['component']),
        source: j['source']?.toString() ?? '',
      );

  Place toPlace() => Place(
        name: name,
        position: position,
        stopId: stopId,
        component: component,
      );
}
