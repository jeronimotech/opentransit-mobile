import '../models/models.dart';

/// When a saved route may raise a local notification.
enum AlertSchedule {
  always,
  weekdays,
  workHours,
  never;

  String get wire => name;

  static AlertSchedule parse(Object? v) => switch (v?.toString()) {
        'always' => always,
        'weekdays' => weekdays,
        'workHours' => workHours,
        _ => never,
      };
}

/// Working window used by [AlertSchedule.workHours]: weekdays, 06:00–20:00.
/// Deliberately fixed rather than configurable — a per-route custom schedule
/// is a settings screen nobody fills in.
const _workStartHour = 6;
const _workEndHour = 20;

bool _isWeekday(DateTime t) => t.weekday >= DateTime.monday && t.weekday <= DateTime.friday;

/// Does [schedule] allow notifying at [now]?
bool scheduleAllows(AlertSchedule schedule, DateTime now) => switch (schedule) {
      AlertSchedule.always => true,
      AlertSchedule.weekdays => _isWeekday(now),
      AlertSchedule.workHours =>
        _isWeekday(now) && now.hour >= _workStartHour && now.hour < _workEndHour,
      AlertSchedule.never => false,
    };

/// Is [a] in force at [now]? Alerts without a period are treated as active,
/// which is what the API already does for the alerts list.
bool alertActiveAt(TransitAlert a, DateTime now) {
  if (a.start != null && now.isBefore(a.start!)) return false;
  if (a.end != null && now.isAfter(a.end!)) return false;
  return true;
}

/// One notification the app should raise: an alert on a saved route that the
/// schedule allows and that has not been shown too often today.
class RouteAlertHit {
  const RouteAlertHit({required this.routeId, required this.alert});
  final String routeId;
  final TransitAlert alert;

  /// Stable dedup key: the same alert on the same route is one notification.
  String get key => '$routeId|${alert.id}';
}

/// Per-route notification bookkeeping for one day, as persisted.
typedef AlertLog = Map<String, dynamic>;

/// Picks what to notify.
///
/// * only alerts touching a saved route whose [schedules] entry allows [now]
/// * only alerts in force at [now]
/// * never the same (route, alert) twice — [seenKeys]
/// * at most [maxPerRoutePerDay] notifications per route per day — [countsToday]
///
/// Pure so the policy is unit-tested rather than observed in the wild.
List<RouteAlertHit> routeAlertsToNotify({
  required List<TransitAlert> alerts,
  required Map<String, AlertSchedule> schedules,
  required DateTime now,
  Set<String> seenKeys = const {},
  Map<String, int> countsToday = const {},
  int maxPerRoutePerDay = 3,
}) {
  final out = <RouteAlertHit>[];
  final used = <String, int>{...countsToday};
  for (final a in alerts) {
    if (!alertActiveAt(a, now)) continue;
    for (final routeId in a.routeIds) {
      final schedule = schedules[routeId];
      if (schedule == null || !scheduleAllows(schedule, now)) continue;
      final hit = RouteAlertHit(routeId: routeId, alert: a);
      if (seenKeys.contains(hit.key)) continue;
      if ((used[routeId] ?? 0) >= maxPerRoutePerDay) continue;
      used[routeId] = (used[routeId] ?? 0) + 1;
      out.add(hit);
    }
  }
  return out;
}
