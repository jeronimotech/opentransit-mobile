import 'common.dart';
import 'ondemand.dart';
import 'rental.dart';
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
    this.rentalStationId,
  });
  final String name;
  final LatLng position;
  final String? stopId;
  final String? stopCode;
  final DateTime? arrival;
  final DateTime? departure;
  final Component? component;

  /// Set when this place is a shared-bike docking station (v1.2).
  final String? rentalStationId;

  bool get isStop => stopId != null;
  bool get isRentalStation => rentalStationId != null;

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        name: j['name']?.toString() ?? '',
        position: LatLng.fromJson(j),
        stopId: j['stopId']?.toString(),
        stopCode: j['stopCode']?.toString(),
        arrival: parseTime(j['arrival']),
        departure: parseTime(j['departure']),
        component: Component.parse(j['component']),
        rentalStationId: j['rentalStationId']?.toString(),
      );

  Place copyWith({String? name, DateTime? arrival, DateTime? departure}) => Place(
        name: name ?? this.name,
        position: position,
        stopId: stopId,
        stopCode: stopCode,
        arrival: arrival ?? this.arrival,
        departure: departure ?? this.departure,
        component: component,
        rentalStationId: rentalStationId,
      );

  /// Same place with its times moved by [delta] (client-side re-timing).
  Place shifted(Duration delta) => Place(
        name: name,
        position: position,
        stopId: stopId,
        stopCode: stopCode,
        arrival: arrival?.add(delta),
        departure: departure?.add(delta),
        component: component,
        rentalStationId: rentalStationId,
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
    this.rental,
    this.onDemand,
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

  /// Shared-vehicle block for rental legs (v1.2); null for own bike / walk.
  final LegRental? rental;

  /// Taxi / ride-hailing options for a CAR leg (v1.4); null otherwise.
  final LegOnDemand? onDemand;

  bool get isRental => rental != null;
  bool get isOnDemand => onDemand != null;

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
        rental: j['rental'] is Map
            ? LegRental.fromJson(Map<String, dynamic>.from(j['rental'] as Map))
            : null,
        onDemand: j['onDemand'] is Map
            ? LegOnDemand.fromJson(Map<String, dynamic>.from(j['onDemand'] as Map))
            : null,
      );

  /// Colour for this leg: route colour for transit, the network colour for
  /// rental legs, the recommended provider's colour for on-demand legs, null
  /// for walking.
  String? get colorHex => route?.color ?? rental?.color ?? onDemand?.recommended?.color;

  Leg copyWith({
    Place? from,
    Place? to,
    DateTime? startTime,
    DateTime? endTime,
    List<Place>? intermediateStops,
    bool? realtime,
    RealtimeState? realtimeState,
    String? tripId,
  }) =>
      Leg(
        mode: mode, transit: transit, startTime: startTime ?? this.startTime, endTime: endTime ?? this.endTime,
        durationSeconds: durationSeconds, distanceMeters: distanceMeters,
        from: from ?? this.from, to: to ?? this.to, route: route, headsign: headsign, agency: agency,
        tripId: tripId ?? this.tripId, realtime: realtime ?? this.realtime,
        realtimeState: realtimeState ?? this.realtimeState, delaySeconds: delaySeconds,
        geometry: geometry, intermediateStops: intermediateStops ?? this.intermediateStops, steps: steps, alerts: alerts,
        rental: rental, onDemand: onDemand,
      );

  /// The same leg moved by [delta] (all times, including the places' and the
  /// intermediate stops'). Used when the user picks another live departure.
  Leg shifted(Duration delta, {bool? realtime, String? tripId}) => copyWith(
        startTime: startTime.add(delta),
        endTime: endTime.add(delta),
        from: from.shifted(delta),
        to: to.shifted(delta),
        intermediateStops: [for (final s in intermediateStops) s.shifted(delta)],
        realtime: realtime,
        tripId: tripId,
      );
}

class FareLine {
  const FareLine({required this.label, required this.amount, this.kind});
  final String label;
  final num amount;

  /// `transit | rental | ondemand | null` (v1.2 / v1.4).
  final String? kind;

  bool get isRental => kind == 'rental';
  bool get isOnDemand => kind == 'ondemand';

  factory FareLine.fromJson(Map<String, dynamic> j) => FareLine(
      label: j['label']?.toString() ?? '',
      amount: (j['amount'] as num?) ?? 0,
      kind: j['kind']?.toString());
}

class Fare {
  const Fare({
    required this.amount,
    required this.currency,
    this.estimated = false,
    this.breakdown = const [],
    this.note,
  });

  /// Null when the price is only known inside a provider's app (v1.4
  /// on-demand itineraries without an estimate); see [note].
  final num? amount;
  final String currency;

  /// True when computed from city parameters rather than GTFS fares.
  final bool estimated;
  final List<FareLine> breakdown;

  /// Free text from the API, e.g. "Precio en la app".
  final String? note;

  bool get hasAmount => amount != null;

  factory Fare.fromJson(Map<String, dynamic> j) => Fare(
        amount: j['amount'] as num?,
        currency: j['currency']?.toString() ?? '',
        estimated: asBool(j['estimated']),
        breakdown: asList(j['breakdown'], FareLine.fromJson),
        note: j['note']?.toString(),
      );
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
    this.rentalLegs,
    this.modesUsed = const [],
    this.source,
    this.retimed = false,
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

  /// v1.2 summary fields; derived from the legs when the API omits them.
  final int? rentalLegs;
  final List<String> modesUsed;

  /// Diagnostic origin of the itinerary (`primary | rental | ondemand`).
  final String? source;

  /// True after the user re-timed it from the live departure chips (client
  /// side; never comes from the API).
  final bool retimed;

  Itinerary copyWith({
    List<Leg>? legs,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    bool? retimed,
  }) =>
      Itinerary(
        id: id,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        walkDistanceMeters: walkDistanceMeters,
        walkTimeSeconds: walkTimeSeconds,
        waitingTimeSeconds: waitingTimeSeconds,
        transfers: transfers,
        fare: fare,
        accessible: accessible,
        legs: legs ?? this.legs,
        rentalLegs: rentalLegs,
        modesUsed: modesUsed,
        source: source,
        retimed: retimed ?? this.retimed,
      );

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
        rentalLegs: asInt(j['rentalLegs']),
        modesUsed: asStrings(j['modesUsed']),
        source: j['source']?.toString(),
      );

  Iterable<Leg> get transitLegs => legs.where((l) => l.transit);
  Iterable<Leg> get rentalLegList => legs.where((l) => l.isRental);
  Iterable<Leg> get onDemandLegList => legs.where((l) => l.isOnDemand);
  bool get hasRental => rentalLegs != null ? rentalLegs! > 0 : legs.any((l) => l.isRental);

  /// True when the itinerary uses a taxi / ride-hailing leg (v1.4).
  bool get hasOnDemand => modesUsed.contains('CAR_ONDEMAND') || legs.any((l) => l.isOnDemand);

  /// The on-demand leg whose price drives the card (first one).
  LegOnDemand? get onDemand => onDemandLegList.firstOrNull?.onDemand;

  /// A direct ride: one on-demand leg and no transit at all.
  bool get isOnDemandDirect => hasOnDemand && !legs.any((l) => l.transit);
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
    this.onDemand = false,
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

  /// Ask the router for taxi / ride-hailing options too (v1.4 `onDemand=true`).
  final bool onDemand;

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
        if (onDemand) 'onDemand': 'true',
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
