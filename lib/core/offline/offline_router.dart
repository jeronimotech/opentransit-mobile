import 'offline_patterns.dart';

/// One boarding in a journey found without a network.
class OfflineRide {
  const OfflineRide({
    required this.patternIndex,
    required this.fromStop,
    required this.toStop,
    required this.departureMinute,
    required this.arrivalMinute,
  });

  final int patternIndex;

  /// Indices into [OfflinePatterns.stops].
  final int fromStop;
  final int toStop;
  final int departureMinute;
  final int arrivalMinute;
}

/// A journey: the rides, in order, with the walk at each end left to the caller.
class OfflineJourney {
  const OfflineJourney({required this.rides, required this.arrivalMinute, this.walkMinutes = 0});
  final List<OfflineRide> rides;

  /// When the rider actually arrives, walking included. Derived from the last ride it was not:
  /// a journey that ends with a three-minute walk from the stop the bus reached would have
  /// reported the bus's arrival and been wrong by exactly the walk.
  final int arrivalMinute;

  /// Minutes spent walking between stops, the part no ride accounts for.
  final int walkMinutes;

  int get departureMinute => rides.first.departureMinute;
  int get transfers => rides.length - 1;
}

/// RAPTOR over the pattern index: plan a trip with no network.
///
/// Round k holds the best arrival time reachable using at most k boardings, so the first round that
/// reaches the destination is also the one with the fewest transfers — which is why this returns a
/// journey per round rather than only the fastest. A rider offered "40 min, 2 changes" and "46 min,
/// direct" should get to choose; a planner that only answers the first is answering a question
/// nobody asked.
///
/// Walking is a transfer between stops within [transferMetres], passed in as a prepared adjacency
/// because the distances come from the board bundle's coordinates and computing them per search
/// would dominate the search.
List<OfflineJourney> planOffline({
  required OfflinePatterns data,
  required Set<int> originStops,
  required Set<int> destinationStops,
  required int departAfterMinute,
  required Set<int> runningServices,
  required List<List<({int stop, int minutes})>> footpaths,
  int maxRounds = 4,
  int transferPenaltyMinutes = 2,
}) {
  if (originStops.isEmpty || destinationStops.isEmpty) return const [];

  final best = List<int>.filled(data.stops.length, _never);
  // How each stop was reached in the round being built, so a journey can be walked back.
  var reachedBy = <int, _Arrival>{};
  final journeys = <OfflineJourney>[];

  var frontier = <int>{};
  for (final s in originStops) {
    if (s < 0 || s >= best.length) continue;
    best[s] = departAfterMinute;
    frontier.add(s);
    _walk(s, departAfterMinute, null, footpaths, best, reachedBy, frontier);
  }

  var bestArrival = _never;
  for (var round = 0; round < maxRounds && frontier.isNotEmpty; round++) {
    final nextReached = <int, _Arrival>{};
    final nextFrontier = <int>{};

    // Every pattern touched by the frontier, boarded at the earliest stop that helps.
    final seenPatterns = <int>{};
    for (final stop in frontier) {
      for (final p in data.patternsAt(stop)) {
        if (!seenPatterns.add(p)) continue;
        _ridePattern(data, p, best, runningServices, nextReached, nextFrontier,
            transferPenaltyMinutes, footpaths);
      }
    }

    for (final e in nextReached.entries) {
      if (e.value.time < best[e.key]) best[e.key] = e.value.time;
    }
    reachedBy = {...reachedBy, ...nextReached};

    final arrival = destinationStops
        .where((s) => s >= 0 && s < best.length)
        .map((s) => best[s])
        .fold(_never, (a, b) => a < b ? a : b);
    if (arrival < bestArrival) {
      bestArrival = arrival;
      final j = _rebuild(destinationStops, best, reachedBy);
      if (j != null) journeys.add(j);
    }
    frontier = nextFrontier;
  }
  return journeys;
}

const int _never = 1 << 30;

class _Arrival {
  const _Arrival(this.time, this.ride, {this.walkMinutes = 0});
  final int time;
  final OfflineRide? ride;

  /// Set when the last step to this stop was on foot.
  final int walkMinutes;
}

void _ridePattern(
  OfflinePatterns data,
  int patternIndex,
  List<int> best,
  Set<int> runningServices,
  Map<int, _Arrival> reached,
  Set<int> frontier,
  int transferPenalty,
  List<List<({int stop, int minutes})>> footpaths,
) {
  final pattern = data.patterns[patternIndex];
  OfflineTrip? trip;
  var boardedAt = -1;

  for (var i = 0; i < pattern.stops.length; i++) {
    final stop = pattern.stops[i];
    if (trip != null) {
      final arrival = trip.times[i];
      if (arrival < best[stop] && arrival < (reached[stop]?.time ?? _never)) {
        reached[stop] = _Arrival(
          arrival,
          OfflineRide(
            patternIndex: patternIndex,
            fromStop: pattern.stops[boardedAt],
            toStop: stop,
            departureMinute: trip.times[boardedAt],
            arrivalMinute: arrival,
          ),
        );
        frontier.add(stop);
        _walk(stop, arrival, reached[stop]!.ride, footpaths, best, reached, frontier);
      }
    }
    // Boarding here can only help if we are already here earlier than this trip leaves.
    final here = best[stop];
    if (here == _never) continue;
    final candidate = pattern.earliestTrip(i, here + (trip == null ? 0 : transferPenalty), runningServices);
    if (candidate == null) continue;
    if (trip == null || candidate.times[i] < trip.times[i]) {
      trip = candidate;
      boardedAt = i;
    }
  }
}

/// Walking from a stop reaches its neighbours without using a boarding.
void _walk(
  int from,
  int at,
  OfflineRide? by,
  List<List<({int stop, int minutes})>> footpaths,
  List<int> best,
  Map<int, _Arrival> reached,
  Set<int> frontier,
) {
  if (from >= footpaths.length) return;
  for (final f in footpaths[from]) {
    final t = at + f.minutes;
    final known = reached[f.stop]?.time ?? best[f.stop];
    // Not putIfAbsent: a stop already reached by a slower bus must still accept a faster walk, and
    // with putIfAbsent whichever pattern happened to be scanned first won.
    if (t >= known) continue;
    best[f.stop] = t;
    reached[f.stop] = _Arrival(t, by, walkMinutes: f.minutes);
    frontier.add(f.stop);
  }
}

OfflineJourney? _rebuild(Set<int> destinations, List<int> best, Map<int, _Arrival> reachedBy) {
  int? target;
  var bestTime = _never;
  for (final d in destinations) {
    if (d < best.length && best[d] < bestTime) {
      bestTime = best[d];
      target = d;
    }
  }
  if (target == null || bestTime == _never) return null;

  final rides = <OfflineRide>[];
  var walk = 0;
  var cursor = target;
  final guard = <int>{};
  while (true) {
    final a = reachedBy[cursor];
    if (a == null || a.ride == null) break;
    walk += a.walkMinutes;
    rides.insert(0, a.ride!);
    cursor = a.ride!.fromStop;
    // A cycle here would hang the app rather than return a bad answer, which is worse.
    if (!guard.add(cursor)) break;
  }
  return rides.isEmpty
      ? null
      : OfflineJourney(rides: rides, arrivalMinute: bestTime, walkMinutes: walk);
}
