import 'dart:convert';

/// The timetable indexed by pattern, which is what planning a journey needs.
///
/// The board bundle stores times per stop, so it can say when something leaves and never when you
/// arrive: nothing in it links a departure at one stop to an arrival at another. A pattern — one
/// ordered stop sequence with every trip that runs it — restores that link.
///
/// Measured on Bogotá: 1 521 patterns over 181 051 trips and 9 471 772 times. Unlike the board
/// bundle this one *is* held in memory, and that is the trade it asks for: a scan jumps between
/// patterns and stops in an order nothing on disk can predict, so paging it would be slower than
/// the search. The cost is the times, 9.5 M of them at 8 bytes, so roughly 80 MB for the largest
/// city — which is why the download is separate and optional rather than part of every install.
class OfflinePatterns {
  OfflinePatterns({
    required this.city,
    required this.stops,
    required this.routes,
    required this.headsigns,
    required this.services,
    required this.patterns,
  }) : _patternsByStop = _indexByStop(patterns, stops.length);

  final String city;

  /// Stop ids, in the order the pattern stop indices refer to.
  final List<String> stops;
  final List<String> routes;
  final List<String> headsigns;

  /// Service ids, in the order trips refer to. Which of them run on a date is the board bundle's
  /// `OfflineHeader.activeServices` — the same calendar, read once, passed in here.
  final List<String> services;

  final List<OfflinePattern> patterns;
  final List<List<int>> _patternsByStop;

  static List<List<int>> _indexByStop(List<OfflinePattern> patterns, int stopCount) {
    final out = List.generate(stopCount, (_) => <int>[], growable: false);
    for (var p = 0; p < patterns.length; p++) {
      // A pattern that calls at a stop twice — a loop route — is listed once, because boarding it
      // is one decision however many times it passes.
      for (final s in patterns[p].stops.toSet()) {
        if (s >= 0 && s < out.length) out[s].add(p);
      }
    }
    return out;
  }

  List<int> patternsAt(int stopIndex) =>
      stopIndex >= 0 && stopIndex < _patternsByStop.length ? _patternsByStop[stopIndex] : const [];

  static OfflinePatterns parse(String json) {
    final j = jsonDecode(json) as Map<String, dynamic>;
    return OfflinePatterns(
      city: (j['city'] ?? '').toString(),
      stops: [for (final s in (j['stops'] as List? ?? const [])) s.toString()],
      routes: [for (final r in (j['routes'] as List? ?? const [])) r.toString()],
      headsigns: [for (final h in (j['headsigns'] as List? ?? const [])) h.toString()],
      services: [for (final s in (j['services'] as List? ?? const [])) s.toString()],
      patterns: [
        for (final raw in (j['patterns'] as List? ?? const []))
          OfflinePattern.parse(raw as Map<String, dynamic>),
      ],
    );
  }
}

class OfflinePattern {
  const OfflinePattern({
    required this.routeIndex,
    required this.headsignIndex,
    required this.stops,
    required this.trips,
  });

  final int routeIndex;
  final int headsignIndex;

  /// The ordered stops this pattern calls at, as indices into [OfflinePatterns.stops].
  final List<int> stops;

  /// Every trip that runs it, sorted by departure, so a search can stop at the first that works.
  final List<OfflineTrip> trips;

  static OfflinePattern parse(Map<String, dynamic> j) => OfflinePattern(
        routeIndex: (j['r'] as num?)?.toInt() ?? 0,
        headsignIndex: (j['h'] as num?)?.toInt() ?? 0,
        stops: [for (final s in (j['s'] as List? ?? const [])) (s as num).toInt()],
        trips: [
          for (final t in (j['t'] as List? ?? const []))
            OfflineTrip(
              serviceIndex: ((t as List)[0] as num).toInt(),
              times: [for (final x in (t[1] as List)) (x as num).toInt()],
            ),
        ],
      );

  /// The first trip of this pattern that is still boardable at [stopPosition] at [afterMinute], or
  /// null when the day is done.
  ///
  /// Binary search rather than a walk: a busy Bogotá pattern has hundreds of trips, a scan touches
  /// every pattern it can reach, and the difference is the search feeling instant or not.
  OfflineTrip? earliestTrip(int stopPosition, int afterMinute, Set<int> runningServices) {
    var lo = 0, hi = trips.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (trips[mid].times[stopPosition] < afterMinute) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    // Trips are sorted by their *first* departure, which for a pattern whose trips never overtake
    // one another is the same order as at any stop. Where a feed breaks that, walking forward from
    // the binary search's landing point finds the real earliest rather than trusting the index.
    for (var i = lo; i < trips.length; i++) {
      final t = trips[i];
      if (t.times[stopPosition] >= afterMinute && runningServices.contains(t.serviceIndex)) {
        return t;
      }
    }
    return null;
  }
}

class OfflineTrip {
  const OfflineTrip({required this.serviceIndex, required this.times});
  final int serviceIndex;

  /// One time per stop of the pattern, in minutes since the service day's midnight.
  final List<int> times;
}
