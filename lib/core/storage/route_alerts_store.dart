import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../utils/route_alerts.dart';

/// Per-route alert schedules plus the log that caps how often each route may
/// notify. Everything is local: there is no push infrastructure and no server
/// ever learns which routes a person saved.
class RouteAlertsRepository {
  RouteAlertsRepository(this._prefs, {this.maxPerRoutePerDay = 3});
  final SharedPreferences _prefs;
  final int maxPerRoutePerDay;

  static const _schedulesKey = 'routeAlerts.schedules.v1';
  static const _logKey = 'routeAlerts.log.v1';

  Map<String, dynamic> _read(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final m = jsonDecode(raw);
      return m is Map ? Map<String, dynamic>.from(m) : {};
    } catch (_) {
      return {};
    }
  }

  // ── schedules ──

  /// `routeId` (scoped by city) → schedule. Routes absent from the map are
  /// [AlertSchedule.never].
  Map<String, AlertSchedule> schedules(String cityId) {
    final m = _read(_schedulesKey)[cityId];
    if (m is! Map) return const {};
    return {
      for (final e in m.entries) e.key.toString(): AlertSchedule.parse(e.value),
    }..removeWhere((_, v) => v == AlertSchedule.never);
  }

  AlertSchedule scheduleFor(String cityId, String routeId) =>
      schedules(cityId)[routeId] ?? AlertSchedule.never;

  Future<void> setSchedule(String cityId, String routeId, AlertSchedule schedule) async {
    final all = _read(_schedulesKey);
    final city = Map<String, dynamic>.from(all[cityId] as Map? ?? {});
    if (schedule == AlertSchedule.never) {
      city.remove(routeId);
    } else {
      city[routeId] = schedule.wire;
    }
    all[cityId] = city;
    await _prefs.setString(_schedulesKey, jsonEncode(all));
  }

  // ── notification log (per day) ──

  static String _day(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  /// Keys already notified today, and how many notifications each route used.
  ({Set<String> seen, Map<String, int> counts}) logFor(DateTime now) {
    final log = _read(_logKey);
    final today = log[_day(now)];
    if (today is! Map) return (seen: <String>{}, counts: <String, int>{});
    final seen = <String>{...(today['seen'] as List? ?? const []).map((e) => e.toString())};
    final counts = <String, int>{
      for (final e in (today['counts'] as Map? ?? const {}).entries)
        e.key.toString(): (e.value is int ? e.value as int : 0),
    };
    return (seen: seen, counts: counts);
  }

  /// Records [hits] as notified and drops every other day's bookkeeping, so
  /// the log never grows.
  Future<void> record(Iterable<RouteAlertHit> hits, DateTime now) async {
    if (hits.isEmpty) return;
    final day = _day(now);
    final current = logFor(now);
    final seen = {...current.seen};
    final counts = {...current.counts};
    for (final h in hits) {
      seen.add(h.key);
      counts[h.routeId] = (counts[h.routeId] ?? 0) + 1;
    }
    await _prefs.setString(
        _logKey, jsonEncode({day: {'seen': seen.toList(), 'counts': counts}}));
  }

  /// What to notify right now for [cityId], applying schedules and caps.
  List<RouteAlertHit> pending(String cityId, List<TransitAlert> alerts, DateTime now) {
    final sched = schedules(cityId);
    if (sched.isEmpty) return const [];
    final log = logFor(now);
    return routeAlertsToNotify(
      alerts: alerts,
      schedules: sched,
      now: now,
      seenKeys: log.seen,
      countsToday: log.counts,
      maxPerRoutePerDay: maxPerRoutePerDay,
    );
  }
}
