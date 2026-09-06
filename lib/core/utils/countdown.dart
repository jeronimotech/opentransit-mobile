import '../models/models.dart';

/// "Sal en 4 min" · "Sal ahora" · "Ya salió" — the leave-by countdown shown
/// on result cards (Lote 1). Pure, so the ticker and the tests share it.
enum LeaveKind { leaveIn, leaveNow, departed }

class LeaveState {
  const LeaveState(this.kind, this.minutes);
  final LeaveKind kind;

  /// Minutes until departure; 0 for [LeaveKind.leaveNow] and [LeaveKind.departed].
  final int minutes;

  bool get departed => kind == LeaveKind.departed;

  @override
  bool operator ==(Object other) =>
      other is LeaveState && other.kind == kind && other.minutes == minutes;

  @override
  int get hashCode => Object.hash(kind, minutes);

  @override
  String toString() => 'LeaveState($kind, $minutes)';
}

/// Leave-by state for an itinerary that must start at [start].
///
/// * more than 60 s in the future → `leaveIn(N)` with N rounded to minutes
/// * within ±60 s → `leaveNow`
/// * more than 60 s in the past → `departed`
LeaveState leaveState(DateTime start, DateTime now) {
  final s = start.difference(now).inSeconds;
  if (s < -60) return const LeaveState(LeaveKind.departed, 0);
  if (s <= 60) return const LeaveState(LeaveKind.leaveNow, 0);
  return LeaveState(LeaveKind.leaveIn, (s / 60).round());
}

/// Keeps [its] in order but moves the ones whose departure already passed to
/// the end (stable), so live options stay on top as time goes by.
List<Itinerary> demoteDeparted(List<Itinerary> its, DateTime now) {
  final live = <Itinerary>[];
  final gone = <Itinerary>[];
  for (final it in its) {
    (leaveState(it.startTime, now).departed ? gone : live).add(it);
  }
  return [...live, ...gone];
}

/// How many of [its] already departed at [now].
int departedCount(Iterable<Itinerary> its, DateTime now) =>
    its.where((it) => leaveState(it.startTime, now).departed).length;
