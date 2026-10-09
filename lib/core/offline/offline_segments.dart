import '../models/models.dart';
import 'offline_bundle.dart';
import 'offline_patterns.dart';

/// "What else serves this segment", answered from the downloaded pattern index.
///
/// The server answers the same question from OTP; this is the same rule applied to the bundle, so a
/// rider who downloaded the city gets the alternatives underground too. Pattern order is both the
/// direction check and the branch check: a route that calls at both stops on the way back, or on a
/// branch that only reaches one of them, is not an alternative.
SegmentServices? offlineSegmentServices({
  required String cityId,
  required OfflineHeader header,
  required OfflinePatterns patterns,
  required String fromId,
  required String toId,
  String? excludeRouteId,
}) {
  final origins = _family(header, fromId);
  final dests = _family(header, toId);
  if (origins.isEmpty || dests.isEmpty) return null;

  final routesById = {for (final r in header.routes) r.id: r};
  final exclude = excludeRouteId == null
      ? null
      : (excludeRouteId.contains(':') ? excludeRouteId.split(':').skip(1).join(':') : excludeRouteId);

  final best = <String, SegmentService>{};
  final seen = <int>{};
  for (final o in origins) {
    for (final pi in patterns.patternsAt(o)) {
      if (!seen.add(pi)) continue;
      final p = patterns.patterns[pi];
      final board = p.stops.indexWhere(origins.contains);
      if (board < 0) continue;
      var off = -1;
      for (var j = board + 1; j < p.stops.length; j++) {
        if (dests.contains(p.stops[j])) {
          off = j;
          break;
        }
      }
      if (off < 0) continue;
      final routeId = p.routeIndex < patterns.routes.length ? patterns.routes[p.routeIndex] : null;
      if (routeId == null || routeId == exclude) continue;
      final route = routesById[routeId];
      if (route == null) continue;
      final service = SegmentService(
        route: route.toRef(cityId),
        headsign: p.headsignIndex < patterns.headsigns.length ? patterns.headsigns[p.headsignIndex] : null,
        boardAt: _ref(header, cityId, p.stops[board]),
        getOffAt: _ref(header, cityId, p.stops[off]),
        stops: off - board,
      );
      // One entry per route and platform — the actionable unit is where to stand — and of several
      // patterns of one route the one with the fewest stops, so an express is not hidden.
      final key = '$routeId@${p.stops[board]}';
      final cur = best[key];
      if (cur == null || (service.stops ?? 0) < (cur.stops ?? 0)) best[key] = service;
    }
  }
  final services = best.values.toList()
    ..sort((a, b) {
      final c = (a.route.component?.name ?? '').compareTo(b.route.component?.name ?? '');
      return c != 0 ? c : compareNatural(a.route.shortName, b.route.shortName);
    });
  return SegmentServices(
    from: _ref(header, cityId, header.stopIndexById[fromId] ?? -1) ?? SegmentStopRef(id: '$cityId:$fromId'),
    to: _ref(header, cityId, header.stopIndexById[toId] ?? -1) ?? SegmentStopRef(id: '$cityId:$toId'),
    match: SegmentMatch.pattern,
    services: services,
  );
}

/// The stop plus everything sharing its station, as stop indices — a trunk station publishes one
/// stop per platform and the equivalent service often leaves from another of them.
Set<int> _family(OfflineHeader header, String id) {
  final seed = header.stopIndexById[id];
  if (seed == null) return const {};
  final out = {seed};
  final parent = header.stops[seed].parentStationId;
  for (var i = 0; i < header.stops.length; i++) {
    final s = header.stops[i];
    if (parent != null && (s.parentStationId == parent || s.id == parent)) out.add(i);
    if (s.parentStationId == id) out.add(i);
  }
  return out;
}

SegmentStopRef? _ref(OfflineHeader header, String cityId, int index) {
  if (index < 0 || index >= header.stops.length) return null;
  final s = header.stops[index];
  return SegmentStopRef(id: '$cityId:${s.id}', name: s.name, code: s.code);
}

/// 'B9' before 'B74': digit runs compare as numbers, so a route list reads the way signage does.
int compareNatural(String a, String b) {
  final re = RegExp(r'\d+|\D+');
  final xs = re.allMatches(a).map((m) => m[0]!).toList();
  final ys = re.allMatches(b).map((m) => m[0]!).toList();
  for (var i = 0; i < xs.length && i < ys.length; i++) {
    final x = xs[i], y = ys[i];
    final nx = int.tryParse(x), ny = int.tryParse(y);
    final c = (nx != null && ny != null) ? nx.compareTo(ny) : x.compareTo(y);
    if (c != 0) return c;
  }
  return xs.length.compareTo(ys.length);
}
