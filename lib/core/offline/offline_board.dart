import '../models/models.dart';
import '../utils/geo.dart';
import 'offline_bundle.dart';

/// Turn offline departures into the same [BoardResponse] the API would have sent.
///
/// Reusing the wire model rather than inventing an offline one means the stop page, the favourites
/// rows and the honesty labels all work unchanged — and they tell the truth here for free, because
/// every departure comes back `scheduled`. Offline is exactly the state in which nothing is live,
/// and a board that said otherwise would be the worst lie in the app.
BoardResponse offlineBoard({
  required OfflineHeader header,
  required Stop stop,
  required List<OfflineDeparture> departures,
  required String cityId,
  required DateTime at,
  int perRoute = 3,
}) {
  final groups = <String, List<OfflineDeparture>>{};
  final order = <String>[];
  for (final d in departures) {
    final key = '${d.route.id}|${d.headsign}';
    if (!groups.containsKey(key)) order.add(key);
    (groups[key] ??= []).add(d);
  }

  final rows = <BoardRow>[];
  for (final key in order) {
    final deps = groups[key]!..sort((a, b) => a.time.compareTo(b.time));
    rows.add(BoardRow(
      route: deps.first.route.toRef(cityId),
      headsign: deps.first.headsign.isEmpty ? null : deps.first.headsign,
      next: [
        for (final d in deps.take(perRoute))
          BoardTime(
            time: d.time,
            minutes: (d.time.difference(at).inSeconds / 60).round(),
            // Not realtime, and not pretending to be. `source` is what the board's label reads.
            realtime: false,
            source: 'scheduled',
          ),
      ],
    ));
  }
  rows.sort((a, b) {
    if (a.next.isEmpty || b.next.isEmpty) return a.next.length - b.next.length;
    return a.next.first.time.compareTo(b.next.first.time);
  });

  return BoardResponse(
    stop: stop,
    generatedAt: at,
    freshness: const Freshness(realtime: false, offline: true),
    rows: rows,
  );
}


/// The stops near a point, from the downloaded bundle.
///
/// The header already carries every stop with its name and position — it has to, so a rider can
/// search and see them on a map — so finding the nearest ones needs no network and no extra data.
/// Without this the offline timetable is readable and unreachable: the board works, and there is no
/// way to arrive at a board, because the home screen's list and map are both empty.
///
/// Returns them sorted by distance with `distanceMeters` filled, the same shape `/stops/nearby`
/// returns, so the screens do not know which one answered.
List<Stop> offlineNearbyStops(
  OfflineHeader header,
  LatLng at, {
  int radiusMeters = 500,
  int limit = 30,
}) {
  final found = <(double, Stop)>[];
  for (final s in header.stops) {
    final d = haversineMeters(at, s.position);
    if (d > radiusMeters) continue;
    found.add((d, s.copyWith(distanceMeters: d.round())));
  }
  found.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final f in found.take(limit)) f.$2];
}
