import 'common.dart';
import 'plan.dart';

/// One candidate departure returned by `GET /plan/forecast` (v1.7 A1).
class ForecastOption {
  const ForecastOption({
    required this.departAt,
    required this.arriveAt,
    required this.durationSeconds,
    required this.transfers,
    required this.walkMeters,
    required this.modesUsed,
    required this.routeIds,
    this.fare,
    this.realtime = false,
    this.recommended = false,
    this.gapAfterSeconds,
  });

  final DateTime departAt;
  final DateTime arriveAt;
  final int durationSeconds;
  final int transfers;
  final int walkMeters;
  final List<String> modesUsed;
  final List<String> routeIds;
  final Fare? fare;
  final bool realtime;

  /// Earliest arrival among the fastest quartile — the one to highlight.
  final bool recommended;

  /// Wait until the *next* option; when long the client warns about a gap.
  final int? gapAfterSeconds;

  /// The contract flags waits over 20 min as worth surfacing.
  static const gapThresholdSeconds = 20 * 60;

  bool get hasLongGap => (gapAfterSeconds ?? 0) >= gapThresholdSeconds;

  factory ForecastOption.fromJson(Map<String, dynamic> j) => ForecastOption(
        departAt: parseTime(j['departAt']) ?? DateTime.now(),
        arriveAt: parseTime(j['arriveAt']) ?? DateTime.now(),
        durationSeconds: asInt(j['durationSeconds']) ?? 0,
        transfers: asInt(j['transfers']) ?? 0,
        walkMeters: asInt(j['walkMeters']) ?? 0,
        modesUsed: asStrings(j['modesUsed']),
        routeIds: asStrings(j['routeIds']),
        fare: j['fare'] is Map ? Fare.fromJson(Map<String, dynamic>.from(j['fare'] as Map)) : null,
        realtime: asBool(j['realtime']),
        recommended: asBool(j['recommended']),
        gapAfterSeconds: asInt(j['gapAfterSeconds']),
      );
}

/// `long_gap` · `last_service` · `service_ends` — rendered verbatim, the API
/// localises the text.
class ForecastNote {
  const ForecastNote({required this.kind, this.text, this.at});
  final String kind;
  final String? text;
  final DateTime? at;

  factory ForecastNote.fromJson(Map<String, dynamic> j) => ForecastNote(
        kind: j['kind']?.toString() ?? '',
        text: j['text']?.toString(),
        at: parseTime(j['at']) ?? parseTime(j['atrs']),
      );
}

class ForecastResponse {
  const ForecastResponse({
    required this.options,
    this.notes = const [],
    this.generatedAt,
  });
  final List<ForecastOption> options;
  final List<ForecastNote> notes;
  final DateTime? generatedAt;

  bool get isEmpty => options.isEmpty;

  factory ForecastResponse.fromJson(Map<String, dynamic> j) => ForecastResponse(
        options: asList(j['options'], ForecastOption.fromJson),
        notes: asList(j['notes'], ForecastNote.fromJson),
        generatedAt: parseTime(j['generatedAt']),
      );

  /// Client-side fallback for APIs without `/plan/forecast`: derive the
  /// options from itineraries we already have, marking the fastest as
  /// recommended and computing the gaps between consecutive departures.
  factory ForecastResponse.fromItineraries(List<Itinerary> its) {
    final sorted = [...its]..sort((a, b) => a.startTime.compareTo(b.startTime));
    if (sorted.isEmpty) return const ForecastResponse(options: []);
    final fastest = sorted.map((i) => i.durationSeconds).reduce((a, b) => a < b ? a : b);
    // "Fastest quartile" degrades to "within 10 % of the fastest" on a
    // handful of itineraries, which is what the API does for small sets.
    final cutoff = fastest * 1.1;
    ForecastOption? best;
    final options = <ForecastOption>[];
    for (var i = 0; i < sorted.length; i++) {
      final it = sorted[i];
      final gap = i + 1 < sorted.length
          ? sorted[i + 1].startTime.difference(it.startTime).inSeconds
          : null;
      final o = ForecastOption(
        departAt: it.startTime,
        arriveAt: it.endTime,
        durationSeconds: it.durationSeconds,
        transfers: it.transfers,
        walkMeters: it.walkDistanceMeters,
        modesUsed: it.modesUsed,
        routeIds: [for (final l in it.legs) if (l.route != null) l.route!.id],
        fare: it.fare,
        realtime: it.legs.any((l) => l.realtime),
        recommended: false,
        gapAfterSeconds: gap,
      );
      options.add(o);
      if (it.durationSeconds <= cutoff && (best == null || o.arriveAt.isBefore(best.arriveAt))) {
        best = o;
      }
    }
    if (best == null) return ForecastResponse(options: options);
    return ForecastResponse(options: [
      for (final o in options)
        if (identical(o, best))
          ForecastOption(
            departAt: o.departAt, arriveAt: o.arriveAt, durationSeconds: o.durationSeconds,
            transfers: o.transfers, walkMeters: o.walkMeters, modesUsed: o.modesUsed,
            routeIds: o.routeIds, fare: o.fare, realtime: o.realtime,
            recommended: true, gapAfterSeconds: o.gapAfterSeconds,
          )
        else
          o,
    ]);
  }
}
