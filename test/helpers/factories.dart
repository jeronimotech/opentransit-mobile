import 'package:opentransit_mobile/core/models/models.dart';

/// Small builders so tests state only what they care about. Every field has a
/// plausible default; anything a test asserts on is a named argument.

RouteRef routeRef({String id = 'r1', String? shortName, String color = '#D32F2F'}) => RouteRef(
      id: id,
      shortName: shortName ?? id,
      longName: shortName ?? id,
      color: color,
      textColor: '#FFFFFF',
      mode: TravelMode.bus,
      agencyId: '1',
    );

Leg leg({
  TravelMode mode = TravelMode.walk,
  bool transit = false,
  DateTime? start,
  int minutes = 10,
  RouteRef? route,
  String? fromStopId,
  String? toStopId,
  LatLng from = const LatLng(4.60, -74.10),
  LatLng to = const LatLng(4.61, -74.11),
  int distanceMeters = 800,
}) {
  final s = start ?? DateTime(2026, 9, 8, 9, 0);
  final e = s.add(Duration(minutes: minutes));
  return Leg(
    mode: mode,
    transit: transit,
    startTime: s,
    endTime: e,
    durationSeconds: minutes * 60,
    distanceMeters: distanceMeters,
    from: Place(name: 'A', position: from, stopId: fromStopId, departure: s),
    to: Place(name: 'B', position: to, stopId: toStopId, arrival: e),
    route: route,
    realtime: false,
    geometry: const Geometry(encoded: ''),
    intermediateStops: const [],
  );
}

Itinerary itinerary({
  String id = 'it-0',
  DateTime? start,
  DateTime? end,
  List<Leg>? legs,
  int transfers = 0,
  int walkMeters = 500,
}) {
  final s = start ?? DateTime(2026, 9, 8, 9, 0);
  final ls = legs ?? [leg(start: s)];
  final e = end ?? ls.last.endTime;
  return Itinerary(
    id: id,
    startTime: s,
    endTime: e,
    durationSeconds: e.difference(s).inSeconds,
    walkDistanceMeters: walkMeters,
    walkTimeSeconds: 300,
    waitingTimeSeconds: 60,
    transfers: transfers,
    legs: ls,
    modesUsed: [for (final l in ls) l.mode.wire],
  );
}

TransitAlert alert({
  String id = 'a1',
  List<String> routeIds = const [],
  List<String> stopIds = const [],
  String header = 'Desvío en la ruta',
  DateTime? start,
  DateTime? end,
  AlertSeverity severity = AlertSeverity.warning,
}) =>
    TransitAlert(
      id: id,
      severity: severity,
      header: header,
      start: start,
      end: end,
      routeIds: routeIds,
      stopIds: stopIds,
      routes: [for (final r in routeIds) routeRef(id: r)],
    );

Stop stop({
  String id = 's1',
  String name = 'Parada',
  LatLng position = const LatLng(4.60, -74.10),
}) =>
    Stop(id: id, name: name, position: position, locationType: 'stop');

Vehicle vehicle({
  String id = 'v1',
  LatLng position = const LatLng(4.60, -74.10),
  String? routeId,
}) =>
    Vehicle(
      id: id,
      position: position,
      routeId: routeId,
      timestamp: DateTime(2026, 9, 8, 9, 0),
    );
