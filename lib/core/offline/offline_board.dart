import '../models/models.dart';
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
