import '../models/models.dart';

/// Re-times an itinerary client-side so that leg [legIndex] boards at
/// [newStart] (a departure the user picked from the live chips), without a
/// new plan request (Lote 1).
///
/// The chosen leg and everything after it shift by the same delta; the walk
/// (or other non-transit) legs immediately before it shift too, so the
/// "leave by" time follows the new departure. Earlier transit legs are left
/// untouched (they already happened or are fixed).
Itinerary retimeItinerary(Itinerary it, int legIndex, DateTime newStart, {bool? realtime, String? tripId}) {
  if (legIndex < 0 || legIndex >= it.legs.length) return it;
  final delta = newStart.difference(it.legs[legIndex].startTime);
  if (delta == Duration.zero && realtime == null && tripId == null) return it;

  var firstShifted = legIndex;
  while (firstShifted > 0 && !it.legs[firstShifted - 1].transit) {
    firstShifted--;
  }
  final legs = [
    for (var i = 0; i < it.legs.length; i++)
      i < firstShifted
          ? it.legs[i]
          : it.legs[i].shifted(delta, realtime: i == legIndex ? realtime : null, tripId: i == legIndex ? tripId : null),
  ];
  final start = legs.first.startTime;
  final end = legs.last.endTime;
  return it.copyWith(
    legs: legs,
    startTime: start,
    endTime: end,
    durationSeconds: end.difference(start).inSeconds,
    retimed: true,
  );
}
