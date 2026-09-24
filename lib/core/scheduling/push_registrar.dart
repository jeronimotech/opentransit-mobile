import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../storage/route_alerts_store.dart';
import '../storage/scheduled_trips.dart';
import '../utils/notifications.dart';
import '../../l10n/generated/app_localizations.dart';
import 'trip_scheduler.dart';

/// Everything the server may know about this phone: a push token (APNs on iOS, FCM on Android), the
/// instants it wants to be woken (twenty minutes before each scheduled trip leaves, over the next
/// week) and the routes it follows. Nothing else leaves the device. Re-registered whenever any of it
/// changes, and skipped when the same registration was already sent.
class PushRegistrar {
  PushRegistrar({required this.prefs, required this.api, String? platform})
      : platform = platform ?? (defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios');
  final SharedPreferences prefs;
  final ApiClient api;

  /// Which service holds this token, and therefore how it must be treated.
  final String platform;

  static const tokenKey = 'push.token';
  static const sentKey = 'push.lastRegistration';
  static const envKey = 'push.env';
  static const horizon = Duration(days: 7);

  String? get token => prefs.getString(tokenKey);

  /// Stores the token; a previous, different one is unregistered first so a reinstall or a new build
  /// does not leave dead tokens behind on the server.
  ///
  /// Only APNs tokens are folded to lower case: they are hex and Apple hands them back in either
  /// case, so one form in storage keeps the unregister call from missing its row. An FCM token is
  /// mixed-case and carries ':', '-' and '_'; lowercasing one makes it undeliverable.
  Future<void> saveToken(String token, {String env = 'prod'}) async {
    final old = prefs.getString(tokenKey);
    final next = platform == 'ios' ? token.toLowerCase() : token;
    if (old != null && old != next) {
      final cityId = prefs.getString('city');
      if (cityId != null) {
        try {
          await api.unregisterPushDevice(cityId, old);
        } catch (_) {}
      }
      await prefs.remove(sentKey);
    }
    await prefs.setString(tokenKey, next);
    await prefs.setString(envKey, env);
  }

  /// The wake instants for [trips]: every occurrence within the horizon, twenty minutes before its
  /// planned (or assumed) departure.
  static List<DateTime> wakeInstants(List<ScheduledTrip> trips, DateTime now) {
    final out = <DateTime>[];
    for (final t in trips) {
      if (!t.enabled) continue;
      var from = now;
      for (var i = 0; i < 14; i++) {
        final occ = t.nextOccurrence(from);
        if (occ == null || occ.difference(now) > horizon) break;
        final leave = (t.lastPlan != null && t.lastPlan!.occurrence == occ)
            ? t.lastPlan!.leaveAt
            : ReminderTimes.fallbackLeave(occ, arriveBy: t.arriveBy);
        final at = leave.subtract(const Duration(minutes: 20));
        if (at.isAfter(now)) out.add(at.toUtc());
        from = occ.add(const Duration(minutes: 1));
      }
    }
    out.sort();
    return out;
  }

  Map<String, dynamic> registration({required String cityId, required List<ScheduledTrip> trips,
                                     required Iterable<String> routeIds, required Locale locale, required DateTime now}) =>
      {
        'token': token,
        'platform': platform,
        'env': prefs.getString(envKey) ?? 'prod',
        'locale': locale.toString(),
        'wakeAt': [for (final t in wakeInstants(trips.where((t) => t.cityId == cityId).toList(), now)) t.toIso8601String()],
        'routes': routeIds.toList()..sort(),
      };

  /// Registers when something changed; unregisters when there is nothing left to be woken for.
  Future<void> sync({required String cityId, required bool serverReminders, required Locale locale,
                     required DateTime now}) async {
    final tok = token;
    if (tok == null || !serverReminders) return;
    final trips = ScheduledTripsRepository(prefs).load();
    final routes = RouteAlertsRepository(prefs).schedules(cityId).keys;
    final reg = registration(cityId: cityId, trips: trips, routeIds: routes, locale: locale, now: now);
    final empty = (reg['wakeAt'] as List).isEmpty && (reg['routes'] as List).isEmpty;
    final fingerprint = jsonEncode(reg);
    if (prefs.getString(sentKey) == fingerprint) return;
    try {
      if (empty) {
        await api.unregisterPushDevice(cityId, tok);
      } else {
        await api.registerPushDevice(cityId, reg);
      }
      await prefs.setString(sentKey, fingerprint);
    } catch (e) {
      debugPrint('push registration failed: $e');
    }
  }
}

/// The Android background poll for followed routes (iOS gets an alert push instead): the same pass
/// the foreground watcher makes, from a headless isolate.
Future<int> runRouteAlertCheck({required SharedPreferences prefs, required ApiClient api, required Locale locale,
                                required DateTime now}) async {
  final cityId = prefs.getString('city');
  if (cityId == null) return 0;
  final repo = RouteAlertsRepository(prefs);
  if (repo.schedules(cityId).isEmpty) return 0;
  final alerts = await api.alerts(cityId);
  final hits = repo.pending(cityId, alerts, now);
  if (hits.isEmpty) return 0;
  final l10n = lookupAppLocalizations(locale);
  var id = 3000 + (now.millisecondsSinceEpoch ~/ 1000) % 1000;
  for (final h in hits) {
    final route = h.alert.routes.where((r) => r.id == h.routeId).firstOrNull;
    await LocalNotifications.instance.showWithPayload(id++, l10n.routeAlertNotificationTitle(route?.shortName ?? h.routeId),
        h.alert.header, payload: '/$cityId/alerts');
  }
  await repo.record(hits, now);
  return hits.length;
}
