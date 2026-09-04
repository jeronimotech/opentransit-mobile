import 'common.dart';

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
  });
  final String id;
  final String shortName;
  final String longName;
  final String color;
  final String textColor;
  final TravelMode mode;
  final String agencyId;
  final Component? component;

  factory RouteRef.fromJson(Map<String, dynamic> j) => RouteRef(
        id: j['id'].toString(),
        shortName: j['shortName']?.toString() ?? '',
        longName: j['longName']?.toString() ?? '',
        color: j['color']?.toString() ?? '#607D8B',
        textColor: j['textColor']?.toString() ?? '#FFFFFF',
        mode: TravelMode.parse(j['mode']),
        agencyId: j['agencyId']?.toString() ?? '',
        component: Component.parse(j['component']),
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

  bool get isStation => locationType == 'station';

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
      );
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
    required this.scheduledTime,
    this.realtimeTime,
    required this.realtime,
    this.delaySeconds,
    this.canceled = false,
    this.vehicleId,
    this.stopSequence,
  });
  final RouteRef route;
  final String? headsign;
  final String? tripId;
  final DateTime scheduledTime;
  final DateTime? realtimeTime;
  final bool realtime;
  final int? delaySeconds;
  final bool canceled;
  final String? vehicleId;
  final int? stopSequence;

  DateTime get effectiveTime => realtimeTime ?? scheduledTime;

  factory Departure.fromJson(Map<String, dynamic> j) => Departure(
        route: RouteRef.fromJson(Map<String, dynamic>.from(j['route'] as Map)),
        headsign: j['headsign']?.toString(),
        tripId: j['tripId']?.toString(),
        scheduledTime: parseTime(j['scheduledTime']) ?? DateTime.now(),
        realtimeTime: parseTime(j['realtimeTime']),
        realtime: asBool(j['realtime']),
        delaySeconds: asInt(j['delaySeconds']),
        canceled: asBool(j['canceled']),
        vehicleId: j['vehicleId']?.toString(),
        stopSequence: asInt(j['stopSequence']),
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
