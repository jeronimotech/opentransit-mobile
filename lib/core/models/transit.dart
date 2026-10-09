import 'common.dart';

/// Today's service span for a route (v1.1 `RouteRef.serviceWindow`).
class ServiceWindow {
  const ServiceWindow({
    this.start,
    this.end,
    required this.active,
    this.nextStart,
    this.source,
  });

  /// `HH:mm` local time.
  final String? start;
  final String? end;
  final bool active;

  /// `HH:mm` of the next start when [active] is false, or null when the
  /// route does not run again today.
  final String? nextStart;
  final String? source;

  factory ServiceWindow.fromJson(Map<String, dynamic> j) => ServiceWindow(
        start: j['start']?.toString(),
        end: j['end']?.toString(),
        active: asBool(j['active'], fallback: true),
        nextStart: j['nextStart']?.toString(),
        source: j['source']?.toString(),
      );
}

class RouteRef {
  const RouteRef({
    required this.id,
    required this.shortName,
    required this.longName,
    required this.color,
    required this.textColor,
    required this.mode,
    required this.agencyId,
    this.component,
    this.serviceWindow,
  });
  final String id;
  final String shortName;
  final String longName;
  final String color;
  final String textColor;
  final TravelMode mode;
  final String agencyId;
  final Component? component;
  final ServiceWindow? serviceWindow;

  factory RouteRef.fromJson(Map<String, dynamic> j) => RouteRef(
        id: j['id'].toString(),
        shortName: j['shortName']?.toString() ?? '',
        longName: j['longName']?.toString() ?? '',
        color: j['color']?.toString() ?? '#607D8B',
        textColor: j['textColor']?.toString() ?? '#FFFFFF',
        mode: TravelMode.parse(j['mode']),
        agencyId: j['agencyId']?.toString() ?? '',
        component: Component.parse(j['component']),
        serviceWindow: j['serviceWindow'] is Map
            ? ServiceWindow.fromJson(
                Map<String, dynamic>.from(j['serviceWindow'] as Map))
            : null,
      );

  String get displayName => shortName.isNotEmpty ? shortName : longName;
}

enum WheelchairAccess {
  unknown,
  accessible,
  notAccessible;

  static WheelchairAccess parse(Object? v) => switch (v?.toString()) {
        'accessible' => accessible,
        'not_accessible' => notAccessible,
        _ => unknown,
      };
}

/// Honest accessibility info (v1.1 `Stop.accessibility`).
class StopAccessibility {
  const StopAccessibility({
    this.wheelchair = WheelchairAccess.unknown,
    this.source = 'none',
    this.verified = false,
    this.note,
  });
  final WheelchairAccess wheelchair;

  /// `gtfs | osm | none`
  final String source;
  final bool verified;
  final String? note;

  factory StopAccessibility.fromJson(Map<String, dynamic> j) =>
      StopAccessibility(
        wheelchair: WheelchairAccess.parse(j['wheelchair']),
        source: j['source']?.toString() ?? 'none',
        verified: asBool(j['verified']),
        note: j['note']?.toString(),
      );
}

class Stop {
  const Stop({
    required this.id,
    this.code,
    required this.name,
    required this.position,
    required this.locationType,
    this.component,
    this.wheelchair = WheelchairAccess.unknown,
    this.parentStationId,
    this.distanceMeters,
    this.accessibility,
  });
  final String id;
  final String? code;
  final String name;
  final LatLng position;

  /// `stop | station | entrance`
  final String locationType;
  final Component? component;
  final WheelchairAccess wheelchair;
  final String? parentStationId;

  /// Only set by `/stops/nearby`.
  final int? distanceMeters;
  final StopAccessibility? accessibility;

  bool get isStation => locationType == 'station';

  /// Accessibility block, synthesised from the legacy field when the API
  /// predates v1.1 (then it is by definition unverified).
  StopAccessibility get access =>
      accessibility ??
      StopAccessibility(
        wheelchair: wheelchair,
        source: wheelchair == WheelchairAccess.unknown ? 'none' : 'gtfs',
        verified: false,
      );

  /// Same stop with an inferred component (parent stations come without one).
  Stop withComponent(Component? c) => Stop(
        id: id, code: code, name: name, position: position, locationType: locationType,
        component: c ?? component, wheelchair: wheelchair, parentStationId: parentStationId,
        accessibility: accessibility, distanceMeters: distanceMeters,
      );

  Stop copyWith({int? distanceMeters}) => Stop(
        id: id, code: code, name: name, position: position,
        locationType: locationType, component: component, wheelchair: wheelchair,
        parentStationId: parentStationId, accessibility: accessibility,
        distanceMeters: distanceMeters ?? this.distanceMeters,
      );

  factory Stop.fromJson(Map<String, dynamic> j) => Stop(
        id: j['id'].toString(),
        code: j['code']?.toString(),
        name: j['name']?.toString() ?? '',
        position: LatLng.fromJson(j),
        locationType: j['locationType']?.toString() ?? 'stop',
        component: Component.parse(j['component']),
        wheelchair: WheelchairAccess.parse(j['wheelchair']),
        parentStationId: j['parentStationId']?.toString(),
        distanceMeters: asInt(j['distanceMeters']),
        accessibility: j['accessibility'] is Map
            ? StopAccessibility.fromJson(
                Map<String, dynamic>.from(j['accessibility'] as Map))
            : null,
      );
}

/// Most frequent component among [routes] (null when none carry one).
Component? dominantComponent(Iterable<RouteRef> routes) {
  final counts = <Component, int>{};
  for (final r in routes) {
    final c = r.component;
    if (c != null && c != Component.other) counts[c] = (counts[c] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
}

class StopDetail {
  const StopDetail({
    required this.stop,
    required this.routes,
    this.parentStation,
    this.children = const [],
  });
  final Stop stop;
  final List<RouteRef> routes;
  final Stop? parentStation;
  final List<Stop> children;

  factory StopDetail.fromJson(Map<String, dynamic> j) => StopDetail(
        stop: Stop.fromJson(j),
        routes: asList(j['routes'], RouteRef.fromJson),
        parentStation: j['parentStation'] is Map
            ? Stop.fromJson(Map<String, dynamic>.from(j['parentStation'] as Map))
            : null,
        children: asList(j['children'], Stop.fromJson),
      );
}

class Departure {
  const Departure({
    required this.route,
    this.headsign,
    this.tripId,
    this.scheduledTime,
    this.realtimeTime,
    required this.realtime,
    this.delaySeconds,
    this.canceled = false,
    this.vehicleId,
    this.stopSequence,
    this.realtimeSource,
  });
  final RouteRef route;
  final String? headsign;
  final String? tripId;
  /// Null when a predicted arrival was never paired with a scheduled one — a feed
  /// whose trip ids are not the schedule's can still say a bus is coming. The API
  /// guarantees [realtimeTime] in that case, so [effectiveTime] always has one.
  final DateTime? scheduledTime;
  final DateTime? realtimeTime;
  final bool realtime;
  final int? delaySeconds;
  final bool canceled;
  final String? vehicleId;
  final int? stopSequence;

  /// "trip" when the feed's trip matched the schedule, "stop" when it was paired by
  /// stop and route instead. The two are not equally certain.
  final String? realtimeSource;

  DateTime get effectiveTime => realtimeTime ?? scheduledTime ?? DateTime.now();

  factory Departure.fromJson(Map<String, dynamic> j) => Departure(
        route: RouteRef.fromJson(Map<String, dynamic>.from(j['route'] as Map)),
        headsign: j['headsign']?.toString(),
        tripId: j['tripId']?.toString(),
        scheduledTime: parseTime(j['scheduledTime']),
        realtimeTime: parseTime(j['realtimeTime']),
        realtime: asBool(j['realtime']),
        delaySeconds: asInt(j['delaySeconds']),
        canceled: asBool(j['canceled']),
        vehicleId: j['vehicleId']?.toString(),
        stopSequence: asInt(j['stopSequence']),
        realtimeSource: j['realtimeSource']?.toString(),
      );
}

class DeparturesResponse {
  const DeparturesResponse({
    required this.stop,
    required this.generatedAt,
    required this.departures,
  });
  final Stop stop;
  final DateTime generatedAt;
  final List<Departure> departures;

  factory DeparturesResponse.fromJson(Map<String, dynamic> j) =>
      DeparturesResponse(
        stop: Stop.fromJson(Map<String, dynamic>.from(j['stop'] as Map)),
        generatedAt: parseTime(j['generatedAt']) ?? DateTime.now(),
        departures: asList(j['departures'], Departure.fromJson),
      );
}

class RoutePattern {
  const RoutePattern({
    required this.id,
    this.headsign,
    this.directionId,
    required this.geometry,
    required this.stops,
  });
  final String id;
  final String? headsign;
  final int? directionId;
  final Geometry geometry;
  final List<Stop> stops;

  factory RoutePattern.fromJson(Map<String, dynamic> j) => RoutePattern(
        id: j['id'].toString(),
        headsign: j['headsign']?.toString(),
        directionId: asInt(j['directionId']),
        geometry: j['geometry'] is Map
            ? Geometry.fromJson(Map<String, dynamic>.from(j['geometry'] as Map))
            : const Geometry(encoded: ''),
        stops: asList(j['stops'], Stop.fromJson),
      );
}

class RouteDetail {
  const RouteDetail({
    required this.route,
    required this.patterns,
    required this.alerts,
  });
  final RouteRef route;
  final List<RoutePattern> patterns;
  final List<TransitAlert> alerts;

  factory RouteDetail.fromJson(Map<String, dynamic> j) => RouteDetail(
        route: RouteRef.fromJson(j),
        patterns: asList(j['patterns'], RoutePattern.fromJson),
        alerts: asList(j['alerts'], TransitAlert.fromJson),
      );
}

enum AlertSeverity {
  info,
  warning,
  severe;

  static AlertSeverity parse(Object? v) => switch (v?.toString()) {
        'WARNING' => warning,
        'SEVERE' => severe,
        _ => info,
      };
}

class TransitAlert {
  const TransitAlert({
    required this.id,
    this.cause,
    this.effect,
    required this.severity,
    required this.header,
    this.description,
    this.url,
    this.start,
    this.end,
    required this.routeIds,
    required this.stopIds,
    required this.routes,
  });
  final String id;
  final String? cause;
  final String? effect;
  final AlertSeverity severity;
  final String header;
  final String? description;
  final String? url;
  final DateTime? start;
  final DateTime? end;
  final List<String> routeIds;
  final List<String> stopIds;
  final List<RouteRef> routes;

  factory TransitAlert.fromJson(Map<String, dynamic> j) => TransitAlert(
        id: j['id'].toString(),
        cause: j['cause']?.toString(),
        effect: j['effect']?.toString(),
        severity: AlertSeverity.parse(j['severity']),
        header: j['header']?.toString() ?? '',
        description: j['description']?.toString(),
        url: j['url']?.toString(),
        start: parseTime(j['start']),
        end: parseTime(j['end']),
        routeIds: asStrings(j['routeIds']),
        stopIds: asStrings(j['stopIds']),
        routes: asList(j['routes'], RouteRef.fromJson),
      );

  bool isActiveAt(DateTime now) =>
      (start == null || !start!.isAfter(now)) &&
      (end == null || !end!.isBefore(now));
}

class NetworkShape {
  const NetworkShape({
    required this.id,
    this.routeId,
    this.component,
    this.color,
    required this.geometry,
  });
  final String id;
  final String? routeId;
  final Component? component;
  final String? color;
  final Geometry geometry;

  factory NetworkShape.fromJson(Map<String, dynamic> j) => NetworkShape(
        id: j['id'].toString(),
        routeId: j['routeId']?.toString(),
        component: Component.parse(j['component']),
        color: j['color']?.toString(),
        geometry:
            Geometry.fromJson(Map<String, dynamic>.from(j['geometry'] as Map)),
      );
}

/// One stop as the segment answer names it — enough to tell a rider where to stand.
class SegmentStopRef {
  const SegmentStopRef({required this.id, this.name, this.code});
  final String id;
  final String? name;
  final String? code;

  factory SegmentStopRef.fromJson(Map<String, dynamic> j) => SegmentStopRef(
        id: j['id'].toString(),
        name: j['name']?.toString(),
        code: j['code']?.toString(),
      );

  String get label => (name?.isNotEmpty ?? false) ? name! : id;
}

/// A route that serves the same segment as the leg being shown, so a rider can board whichever
/// comes first. [boardAt] matters: at a station with several platforms the equivalent service
/// commonly leaves from a different one.
class SegmentService {
  const SegmentService({
    required this.route,
    this.headsign,
    this.boardAt,
    this.getOffAt,
    this.stops,
  });
  final RouteRef route;
  final String? headsign;
  final SegmentStopRef? boardAt;
  final SegmentStopRef? getOffAt;
  final int? stops;

  factory SegmentService.fromJson(Map<String, dynamic> j) => SegmentService(
        route: RouteRef.fromJson(j),
        headsign: j['headsign']?.toString(),
        boardAt: j['boardAt'] is Map
            ? SegmentStopRef.fromJson(Map<String, dynamic>.from(j['boardAt'] as Map))
            : null,
        getOffAt: j['getOffAt'] is Map
            ? SegmentStopRef.fromJson(Map<String, dynamic>.from(j['getOffAt'] as Map))
            : null,
        stops: j['stops'] is num ? (j['stops'] as num).toInt() : null,
      );
}

/// How well the server could answer. `pattern` means these services run the segment in this
/// direction; `stop` means only that they call at both stops — the app has to say so.
enum SegmentMatch {
  pattern,
  stop;

  static SegmentMatch parse(Object? v) =>
      v?.toString() == 'stop' ? SegmentMatch.stop : SegmentMatch.pattern;
}

class SegmentServices {
  const SegmentServices({
    required this.from,
    required this.to,
    required this.match,
    required this.services,
  });
  final SegmentStopRef from;
  final SegmentStopRef to;
  final SegmentMatch match;
  final List<SegmentService> services;

  factory SegmentServices.fromJson(Map<String, dynamic> j) => SegmentServices(
        from: SegmentStopRef.fromJson(Map<String, dynamic>.from(j['from'] as Map)),
        to: SegmentStopRef.fromJson(Map<String, dynamic>.from(j['to'] as Map)),
        match: SegmentMatch.parse(j['match']),
        services: asList(j['services'], SegmentService.fromJson),
      );

  bool get isEmpty => services.isEmpty;
}

/// Interval between departures within one hour of service.
class Headway {
  const Headway({required this.min, required this.typical, required this.max});
  final int min;
  final int typical;
  final int max;

  factory Headway.fromJson(Map<String, dynamic> j) => Headway(
        min: (j['min'] as num).toInt(),
        typical: (j['typical'] as num).toInt(),
        max: (j['max'] as num).toInt(),
      );
}

/// One hour of the published schedule.
class ScheduleBand {
  const ScheduleBand({required this.hour, required this.from, required this.to, required this.trips, this.headway});
  final int hour;
  final String from;
  final String to;
  final int trips;

  /// Null when this hour holds the last departure of the day: one bus and nothing after it is a
  /// count, not a wait.
  final Headway? headway;

  factory ScheduleBand.fromJson(Map<String, dynamic> j) => ScheduleBand(
        hour: (j['hour'] as num).toInt(),
        from: j['from']?.toString() ?? '',
        to: j['to']?.toString() ?? '',
        trips: (j['trips'] as num?)?.toInt() ?? 0,
        headway: j['headwayMinutes'] is Map
            ? Headway.fromJson(Map<String, dynamic>.from(j['headwayMinutes'] as Map))
            : null,
      );
}

/// What a rider can change to at one stop of a pattern.
class StopConnections {
  const StopConnections({required this.stopId, this.name, this.code, required this.routes});
  final String stopId;
  final String? name;
  final String? code;
  final List<RouteRef> routes;

  factory StopConnections.fromJson(Map<String, dynamic> j) => StopConnections(
        stopId: j['stopId'].toString(),
        name: j['name']?.toString(),
        code: j['code']?.toString(),
        routes: asList(j['routes'], RouteRef.fromJson),
      );
}

/// What one direction of a route runs on one day, and what connects along it.
class PatternSchedule {
  const PatternSchedule({
    required this.routeId,
    this.patternId,
    this.patternIds = const [],
    this.headsign,
    required this.date,
    required this.trips,
    this.first,
    this.last,
    this.typicalHeadwayMinutes,
    required this.frequent,
    required this.bands,
    required this.departures,
    required this.connections,
  });

  final String routeId;

  /// The longest variant of the direction — where the stop list and the connections come from.
  final String? patternId;

  /// Every shape variant of the direction whose departures were counted. A feed's "pattern" is a
  /// shape, not a direction, and only some variants run on any given day.
  final List<String> patternIds;
  final String? headsign;
  final String date;
  final int trips;
  final String? first;
  final String? last;

  /// The median gap over the day — what a rider turning up at an unknown time most often waits.
  final int? typicalHeadwayMinutes;

  /// Turn up and go, rather than read a timetable.
  final bool frequent;

  final List<ScheduleBand> bands;

  /// Every departure of the day as `HH:mm`.
  final List<String> departures;
  final List<StopConnections> connections;

  factory PatternSchedule.fromJson(Map<String, dynamic> j) => PatternSchedule(
        routeId: j['routeId'].toString(),
        patternId: j['patternId']?.toString(),
        patternIds: asStrings(j['patternIds']),
        headsign: j['headsign']?.toString(),
        date: j['date']?.toString() ?? '',
        trips: (j['trips'] as num?)?.toInt() ?? 0,
        first: j['first']?.toString(),
        last: j['last']?.toString(),
        typicalHeadwayMinutes: (j['typicalHeadwayMinutes'] as num?)?.toInt(),
        frequent: j['frequent'] == true,
        bands: asList(j['bands'], ScheduleBand.fromJson),
        departures: asStrings(j['departures']),
        connections: asList(j['connections'], StopConnections.fromJson),
      );

  /// Connections keyed by stop, for a stop list that shows them inline.
  Map<String, List<RouteRef>> get routesByStop =>
      {for (final c in connections) c.stopId: c.routes};

  bool get isEmpty => trips == 0;
}
