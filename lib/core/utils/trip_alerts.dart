import '../models/models.dart';
import 'route_alerts.dart';

/// Alerts that touch what is left of a trip in progress.
///
/// Asked for by TransMilenio against 1.16.0 (1.5): alerts were read when the trip was planned and
/// never again, so a closure published while the rider was on the first bus reached them as a
/// surprise at the transfer.
///
/// "What is left" starts at the leg being travelled, not the next one: a diversion on the route you
/// are riding is the one that matters most. Legs already behind are dropped, because an alert about
/// them is news the rider cannot act on.
List<TransitAlert> alertsAhead(
  Itinerary itinerary,
  int legIndex,
  List<TransitAlert> alerts, {
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final legs = itinerary.legs.skip(legIndex.clamp(0, itinerary.legs.length)).toList();
  if (legs.isEmpty) return const [];
  final routeIds = {for (final l in legs) if (l.route != null) l.route!.id};
  final stopIds = <String>{};
  for (final l in legs) {
    for (final p in [l.from, l.to, ...l.intermediateStops]) {
      if (p.stopId != null) stopIds.add(p.stopId!);
    }
  }
  // Until the trip's own end rather than "right now": an alert that starts in twenty minutes still
  // lands on a rider who will be on that platform in thirty.
  final until = legs.last.endTime.isAfter(at) ? legs.last.endTime : at;
  final out = <String, TransitAlert>{};
  for (final a in alerts) {
    final touches = a.routeIds.any(routeIds.contains) || a.stopIds.any(stopIds.contains);
    if (!touches) continue;
    final overlaps = (a.start == null || a.start!.isBefore(until)) && (a.end == null || a.end!.isAfter(at));
    if (!overlaps) continue;
    out[a.id] = a;
  }
  final list = out.values.toList()
    ..sort((x, y) {
      final s = _rank(y.severity).compareTo(_rank(x.severity));
      return s != 0 ? s : (x.start ?? at).compareTo(y.start ?? at);
    });
  return list;
}

/// Of [ahead], the ones the plan did not already carry — published after the rider set off, which
/// is the only kind worth interrupting them for.
List<TransitAlert> alertsSincePlanning(Itinerary itinerary, List<TransitAlert> ahead) {
  final known = {for (final l in itinerary.legs) for (final a in l.alerts) a.id};
  return [for (final a in ahead) if (!known.contains(a.id)) a];
}

/// Still in force at [now] — used to drop an alert that expired while the rider travelled.
List<TransitAlert> activeNow(List<TransitAlert> alerts, DateTime now) =>
    [for (final a in alerts) if (alertActiveAt(a, now)) a];

int _rank(AlertSeverity s) => switch (s) {
      AlertSeverity.severe => 2,
      AlertSeverity.warning => 1,
      AlertSeverity.info => 0,
    };
