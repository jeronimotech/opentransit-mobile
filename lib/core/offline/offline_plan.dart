import '../models/models.dart';
import '../utils/geo.dart';
import 'offline_bundle.dart';
import 'offline_patterns.dart';
import 'offline_router.dart';

/// Walking links between stops, which the pattern index does not carry.
///
/// Without them a journey can only change vehicles at the exact same stop, and in a real city the
/// useful change is usually across the street. The coordinates come from the board bundle's header,
/// which has every stop; the pattern index deliberately holds only ids.
///
/// Built once per bundle rather than per search: it is O(stops²) in the worst case, and 8 311 stops
/// squared is not something to do while someone waits. A grid keyed on a cell roughly the size of
/// the radius keeps it near-linear.
List<List<({int stop, int minutes})>> buildFootpaths(
  OfflineHeader header,
  List<String> patternStopIds, {
  int radiusMetres = 400,
  double walkingMetresPerMinute = 80,
}) {
  final positions = <LatLng?>[
    for (final id in patternStopIds)
      header.stopIndexById[id] == null ? null : header.stops[header.stopIndexById[id]!].position,
  ];

  // Cell size in degrees, latitude-only: close enough at any latitude a transit feed covers, and
  // wrong only in the direction of checking a few extra neighbours.
  final cell = radiusMetres / 111320.0;
  final grid = <({int x, int y}), List<int>>{};
  for (var i = 0; i < positions.length; i++) {
    final p = positions[i];
    if (p == null) continue;
    final key = (x: (p.lon / cell).floor(), y: (p.lat / cell).floor());
    (grid[key] ??= []).add(i);
  }

  final out = List.generate(positions.length, (_) => <({int stop, int minutes})>[], growable: false);
  for (var i = 0; i < positions.length; i++) {
    final a = positions[i];
    if (a == null) continue;
    final cx = (a.lon / cell).floor(), cy = (a.lat / cell).floor();
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        for (final j in grid[(x: cx + dx, y: cy + dy)] ?? const <int>[]) {
          if (j == i) continue;
          final b = positions[j]!;
          final d = haversineMeters(a, b);
          if (d > radiusMetres) continue;
          // At least a minute: a zero-cost hop between two stops a metre apart would let a search
          // chain them for free and invent a journey nobody can walk.
          final minutes = (d / walkingMetresPerMinute).ceil().clamp(1, 60);
          out[i].add((stop: j, minutes: minutes));
        }
      }
    }
  }
  return out;
}

/// Turn journeys from the offline scan into the `PlanResponse` the API would have sent, so the
/// results screen, the itinerary card and the map all work unchanged.
///
/// Every leg comes back `realtime: false`. Offline is exactly the state in which nothing is live,
/// and the honesty labels then tell the truth for free.
PlanResponse offlinePlanResponse({
  required OfflinePatterns data,
  required OfflineHeader header,
  required List<OfflineJourney> journeys,
  required Place from,
  required Place to,
  required DateTime serviceDay,
  required String cityId,
}) {
  final midnight = DateTime(serviceDay.year, serviceDay.month, serviceDay.day);
  DateTime at(int minute) => midnight.add(Duration(minutes: minute));

  Place placeFor(int stopIndex) {
    final id = stopIndex >= 0 && stopIndex < data.stops.length ? data.stops[stopIndex] : '';
    final hi = header.stopIndexById[id];
    final stop = hi == null ? null : header.stops[hi];
    return Place(
      name: stop?.name ?? id,
      position: stop?.position ?? const LatLng(0, 0),
      stopId: '$cityId:$id',
    );
  }

  // The pattern index stores route *ids*; the board bundle's header stores what a route looks like.
  // Both are already on the device, so the chip gets its real name, colour, component and mode by
  // lookup rather than by shipping the same metadata twice. Without this the chips read "10074"
  // in flat grey, which is the GTFS id and tells a rider nothing.
  final routesById = {for (final r in header.routes) r.id: r};

  final itineraries = <Itinerary>[];
  for (final (i, j) in journeys.indexed) {
    final legs = <Leg>[];
    for (final r in j.rides) {
      final pattern = data.patterns[r.patternIndex];
      final route = pattern.routeIndex < data.routes.length
          ? data.routes[pattern.routeIndex]
          : '';
      final headsign = pattern.headsignIndex < data.headsigns.length
          ? data.headsigns[pattern.headsignIndex]
          : '';
      final fromPlace = placeFor(r.fromStop);
      final toPlace = placeFor(r.toStop);
      final known = routesById[route];
      final ref = known?.toRef(cityId) ??
          RouteRef(
            id: '$cityId:$route',
            shortName: route,
            longName: headsign.isEmpty ? route : headsign,
            color: '#607D8B',
            textColor: '#FFFFFF',
            mode: TravelMode.bus,
            agencyId: '',
          );
      legs.add(Leg(
        // The route's own mode, not an assumed bus: a leg on Line 1 drawn with a bus icon is wrong
        // in every city that has a metro.
        mode: ref.mode,
        transit: true,
        startTime: at(r.departureMinute),
        endTime: at(r.arrivalMinute),
        durationSeconds: (r.arrivalMinute - r.departureMinute) * 60,
        distanceMeters: haversineMeters(fromPlace.position, toPlace.position).round(),
        from: fromPlace,
        to: toPlace,
        route: ref,
        headsign: headsign.isEmpty ? null : headsign,
        // Never live, and not pretending to be.
        realtime: false,
        geometry: const Geometry(encoded: ''),
      ));
    }
    if (legs.isEmpty) continue;
    final start = at(j.departureMinute);
    final end = at(j.arrivalMinute);
    itineraries.add(Itinerary(
      id: 'offline-$i',
      startTime: start,
      endTime: end,
      durationSeconds: end.difference(start).inSeconds,
      walkDistanceMeters: j.walkMinutes * 80,
      walkTimeSeconds: j.walkMinutes * 60,
      // Waiting is whatever the journey is not riding or walking; negative would mean the times
      // disagree, and reporting zero is the honest floor.
      waitingTimeSeconds: (end.difference(start).inSeconds -
              legs.fold(0, (a, l) => a + l.durationSeconds) -
              j.walkMinutes * 60)
          .clamp(0, 1 << 30)
          .toInt(),
      transfers: j.transfers,
      legs: legs,
    ));
  }

  return PlanResponse(
    from: from,
    to: to,
    itineraries: itineraries,
    // Said in the one place every screen already reads, so an offline plan cannot be mistaken for
    // a live one.
    warnings: const ['OFFLINE_PLAN: planned from the downloaded timetable, with no realtime'],
  );
}

/// Search the downloaded stops by name, for when the geocoder cannot be reached.
///
/// Without this the offline planner is unreachable: a rider types an origin, the geocoder is a
/// network call, and the field answers "cannot reach the server". The engine answering in 88 ms
/// behind a search box that cannot be filled is a feature nobody can use.
///
/// Stops only, and said so: the online geocoder also knows addresses, streets and places, and none
/// of that is in the bundle. Offering a stop list and calling it a search would be the quieter lie.
List<GeocodeResult> offlineSearchStops(
  OfflineHeader header,
  String query, {
  required String cityId,
  LatLng? near,
  int limit = 20,
}) {
  final q = _fold(query);
  if (q.isEmpty) return const [];

  final hits = <({int score, double distance, Stop stop})>[];
  for (final s in header.stops) {
    final name = _fold(s.name);
    final code = _fold(s.code ?? '');
    // Ranked, not just filtered: someone typing "porta" wants Portal Suba before Transversal
    // Portales, and a code match is the most deliberate thing they can type.
    final int score;
    if (code.isNotEmpty && code == q) {
      score = 0;
    } else if (name.startsWith(q)) {
      score = 1;
    } else if (name.contains(' $q')) {
      score = 2;
    } else if (name.contains(q)) {
      score = 3;
    } else {
      continue;
    }
    hits.add((
      score: score,
      distance: near == null ? 0 : haversineMeters(near, s.position),
      stop: s,
    ));
  }

  hits.sort((a, b) {
    final byScore = a.score.compareTo(b.score);
    return byScore != 0 ? byScore : a.distance.compareTo(b.distance);
  });

  return [
    for (final h in hits.take(limit))
      GeocodeResult(
        id: '$cityId:${h.stop.id}',
        name: h.stop.name,
        position: h.stop.position,
        type: h.stop.locationType == 'station' ? 'station' : 'stop',
        stopId: '$cityId:${h.stop.id}',
        source: 'gtfs',
        distanceMeters: near == null ? null : h.distance.round(),
      ),
  ];
}

/// Lower-cased and stripped of the accents a rider will not type.
String _fold(String s) {
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const to = 'aaaaaeeeeiiiiooooouuuunc';
  final buf = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    final i = from.indexOf(ch);
    buf.write(i >= 0 ? to[i] : ch);
  }
  return buf.toString().trim();
}
