import 'dart:ui' show DartPluginRegistrant, Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../api/api_client.dart';
import '../api/http_api_client.dart';
import '../config.dart';
import '../models/models.dart';
import '../storage/scheduled_trips.dart';
import '../utils/notifications.dart';
import '../../l10n/generated/app_localizations.dart';
import 'push_registrar.dart';

/// Where reminders go. `LocalNotifications` in the app; a memory sink in tests.
abstract class ReminderSink {
  Future<bool> schedule(int id, String title, String body, DateTime when, {String? payload});
  Future<void> show(int id, String title, String body, {String? payload});
  Future<void> cancel(int id);
}

class LocalReminderSink implements ReminderSink {
  const LocalReminderSink();
  @override
  Future<bool> schedule(int id, String title, String body, DateTime when, {String? payload}) =>
      LocalNotifications.instance.schedule(id, title, body, when, payload: payload);
  @override
  Future<void> show(int id, String title, String body, {String? payload}) =>
      LocalNotifications.instance.showWithPayload(id, title, body, payload: payload);
  @override
  Future<void> cancel(int id) => LocalNotifications.instance.cancel(id);
}

class MemoryReminderSink implements ReminderSink {
  final scheduled = <int, ({String title, String body, DateTime when, String? payload})>{};
  final shown = <({int id, String title, String body, String? payload})>[];
  @override
  Future<bool> schedule(int id, String title, String body, DateTime when, {String? payload}) async {
    scheduled[id] = (title: title, body: body, when: when, payload: payload);
    return true;
  }
  @override
  Future<void> show(int id, String title, String body, {String? payload}) async =>
      shown.add((id: id, title: title, body: body, payload: payload));
  @override
  Future<void> cancel(int id) async => scheduled.remove(id);
}

/// The background job that refreshes a reminder with live data shortly before leaving.
/// Android runs one exact-ish job per trip (WorkManager, `initialDelay`); iOS only offers an
/// opportunistic periodic refresh (BGAppRefresh), so there the job is registered once and looks for
/// whatever is due when it runs.
abstract class BackgroundJobs {
  Future<void> scheduleRefresh(String tripId, DateTime at, DateTime now);
  Future<void> cancelRefresh(String tripId);
  Future<void> ensurePeriodic();

  /// Android only: poll the followed routes' alerts every 15 minutes while any route is followed.
  Future<void> ensureAlertPoll(bool needed);
}

class NoBackgroundJobs implements BackgroundJobs {
  const NoBackgroundJobs();
  @override
  Future<void> scheduleRefresh(String tripId, DateTime at, DateTime now) async {}
  @override
  Future<void> cancelRefresh(String tripId) async {}
  @override
  Future<void> ensurePeriodic() async {}
  @override
  Future<void> ensureAlertPoll(bool needed) async {}
}

class WorkmanagerJobs implements BackgroundJobs {
  const WorkmanagerJobs();
  static const taskName = 'tripRefresh';
  static const alertTaskName = 'routeAlertsPoll';
  static const periodicName = 'com.jeronimotech.opentransit.tripRefresh';

  bool get _android => defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> scheduleRefresh(String tripId, DateTime at, DateTime now) async {
    if (!_android) return;                       // iOS: the periodic refresh covers it
    final delay = at.difference(now);
    if (delay.isNegative) return;
    try {
      await Workmanager().registerOneOffTask(
        'trip-$tripId', taskName,
        initialDelay: delay,
        inputData: {'tripId': tripId},
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (e) {
      debugPrint('background refresh not scheduled: $e');
    }
  }

  @override
  Future<void> cancelRefresh(String tripId) async {
    if (!_android) return;
    try {
      await Workmanager().cancelByUniqueName('trip-$tripId');
    } catch (_) {}
  }

  @override
  Future<void> ensureAlertPoll(bool needed) async {
    if (!_android) return;
    try {
      if (needed) {
        await Workmanager().registerPeriodicTask(alertTaskName, alertTaskName,
            frequency: const Duration(minutes: 15), existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
            constraints: Constraints(networkType: NetworkType.connected));
      } else {
        await Workmanager().cancelByUniqueName(alertTaskName);
      }
    } catch (e) {
      debugPrint('alert poll not registered: $e');
    }
  }

  @override
  Future<void> ensurePeriodic() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await Workmanager().registerPeriodicTask(periodicName, taskName, frequency: const Duration(minutes: 15));
    } catch (e) {
      debugPrint('periodic refresh not registered: $e');
    }
  }
}

/// When each reminder fires for one occurrence.
class ReminderTimes {
  /// 21:00 the evening before, when the trip is not today and that hour is still ahead.
  static DateTime? eveningBefore(DateTime occurrence, DateTime now) {
    final eve = DateTime(occurrence.year, occurrence.month, occurrence.day - 1, 21, 0);
    if (!eve.isAfter(now)) return null;
    if (occurrence.year == now.year && occurrence.month == now.month && occurrence.day == now.day) return null;
    return eve;
  }

  /// Twenty minutes before leaving: the live check that adjusts the "leave now" reminder.
  static DateTime? refreshAt(DateTime leaveAt, DateTime now) {
    final at = leaveAt.subtract(const Duration(minutes: 20));
    return at.isAfter(now.add(const Duration(minutes: 1))) ? at : null;
  }

  /// Without a plan (the network was down) assume a typical city trip so the reminder still exists.
  static DateTime fallbackLeave(DateTime occurrence, {required bool arriveBy}) =>
      arriveBy ? occurrence.subtract(const Duration(minutes: 45)) : occurrence;
}

/// Notification ids: three per trip, well above the ids the follow-along and route alerts use.
int reminderBaseId(String tripId) => 1000000 + (tripId.hashCode & 0xFFFFF) * 4;
int eveId(String tripId) => reminderBaseId(tripId) + 1;
int leaveId(String tripId) => reminderBaseId(tripId) + 2;
int refineId(String tripId) => reminderBaseId(tripId) + 3;

String _hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Deep link the reminders open: the planner with both ends and the pinned time, which plans itself.
/// With [go], the "time to leave" reminder, the app continues straight into GO — Live Activity,
/// Dynamic Island and the watch — with the itinerary the reminder was built on.
String tripLocation(ScheduledTrip t, DateTime occurrence, {bool go = false}) {
  final q = {
    'fromLat': t.from.position.lat.toStringAsFixed(5), 'fromLon': t.from.position.lon.toStringAsFixed(5),
    'fromName': t.from.name, 'toLat': t.to.position.lat.toStringAsFixed(5),
    'toLon': t.to.position.lon.toStringAsFixed(5), 'toName': t.to.name,
    'time': occurrence.toIso8601String(), if (t.arriveBy) 'arriveBy': 'true', if (go) 'go': '1',
  };
  return Uri(path: '/${t.cityId}/plan', queryParameters: q).toString();
}

/// The next scheduled trip across [trips], for the watch face: the earliest upcoming departure.
WatchNextTripInfo? nextScheduledTrip(List<ScheduledTrip> trips, DateTime now) {
  WatchNextTripInfo? best;
  for (final t in trips) {
    if (!t.enabled) continue;
    final occ = t.nextOccurrence(now);
    if (occ == null) continue;
    final p = t.lastPlan != null && t.lastPlan!.occurrence == occ ? t.lastPlan : null;
    final leave = p?.leaveAt ?? ReminderTimes.fallbackLeave(occ, arriveBy: t.arriveBy);
    if (!leave.isAfter(now.subtract(const Duration(minutes: 5)))) continue;
    final info = WatchNextTripInfo(leaveAt: leave, arriveAt: p?.arriveAt ?? occ, toName: t.to.name, routes: p?.routes ?? const []);
    if (best == null || info.leaveAt.isBefore(best.leaveAt)) best = info;
  }
  return best;
}

class WatchNextTripInfo {
  const WatchNextTripInfo({required this.leaveAt, required this.arriveAt, required this.toName, required this.routes});
  final DateTime leaveAt;
  final DateTime arriveAt;
  final String toName;
  final List<String> routes;
}

class TripScheduler {
  TripScheduler({required this.repo, required this.api, required this.reminders, required this.jobs,
                 required this.locale});
  final ScheduledTripsRepository repo;
  final ApiClient api;
  final ReminderSink reminders;
  final BackgroundJobs jobs;
  final Locale locale;

  AppLocalizations get l10n => lookupAppLocalizations(locale);

  /// Ask the planner about one occurrence. Null when the network or the planner had nothing. With
  /// [notBefore], only departures from then on count (the live check must never say "sal a las 06:42"
  /// at 07:34).
  Future<ScheduledTripPlan?> plan(ScheduledTrip t, DateTime occurrence, DateTime now, {DateTime? notBefore}) async {
    try {
      final res = await api.plan(t.cityId, PlanRequest(
        from: t.from, to: t.to, time: occurrence, arriveBy: t.arriveBy,
        modes: t.modes.map(TravelMode.parse).toList(), onDemand: t.onDemand,
        numItineraries: 6, locale: locale.languageCode,
      ));
      return ScheduledTripPlan.pick(res.itineraries, occurrence: occurrence, arriveBy: t.arriveBy, now: now,
                                    notBefore: notBefore);
    } catch (e) {
      debugPrint('scheduled trip plan failed: $e');
      return null;
    }
  }

  /// (Re)arm every reminder from what is stored: after a change, at app start (reboots and updates
  /// drop scheduled notifications on Android), and from the background refresh. Returns the trips
  /// with their refreshed plans, already saved.
  Future<List<ScheduledTrip>> sync({required DateTime now, bool replan = true}) async {
    final trips = repo.load();
    final out = <ScheduledTrip>[];
    var anyActive = false;
    for (final t in trips) {
      await reminders.cancel(eveId(t.id));
      await reminders.cancel(leaveId(t.id));
      await jobs.cancelRefresh(t.id);
      final occ = t.enabled ? t.nextOccurrence(now) : null;
      if (occ == null) {
        out.add(t);
        continue;
      }
      anyActive = true;
      var p = t.lastPlan;
      final stale = p == null || p.occurrence != occ ||
          (replan && now.difference(p.computedAt) > const Duration(hours: 6));
      if (stale) {
        p = await plan(t, occ, now) ?? (p != null && p.occurrence == occ ? p : null);
      }
      final trip = t.copyWith(lastPlan: p, clearPlan: p == null);
      out.add(trip);
      await _arm(trip, occ, now);
    }
    await repo.save(out);
    if (anyActive) await jobs.ensurePeriodic();
    return out;
  }

  Future<void> _arm(ScheduledTrip t, DateTime occ, DateTime now) async {
    final p = t.lastPlan;
    final leaveAt = p?.leaveAt ?? ReminderTimes.fallbackLeave(occ, arriveBy: t.arriveBy);
    final arriveAt = p?.arriveAt ?? occ;
    final routes = p?.routesLabel ?? '';
    final link = tripLocation(t, occ);
    final eve = ReminderTimes.eveningBefore(occ, now);
    if (eve != null) {
      await reminders.schedule(eveId(t.id), l10n.tripEveTitle(t.to.name),
          l10n.tripEveBody(_hm(leaveAt), _hm(arriveAt), routes), eve, payload: link);
    }
    await reminders.schedule(leaveId(t.id), l10n.tripLeaveTitle,
        l10n.tripLeaveBody(t.to.name, routes, _hm(arriveAt)), leaveAt, payload: tripLocation(t, occ, go: true));
    final refresh = ReminderTimes.refreshAt(leaveAt, now);
    if (refresh != null) await jobs.scheduleRefresh(t.id, refresh, now);
  }

  /// How far ahead of leaving the live check acts, and how long after (a late wake-up still helps
  /// while the rider can still catch something).
  static const refreshAhead = Duration(minutes: 40);
  static const refreshGrace = Duration(minutes: 5);

  /// Whether the live check should act on a trip now: its departure is within [refreshAhead] and not
  /// more than [refreshGrace] gone. The background job runs when iOS lets it, which can be an hour
  /// late; acting then on a trip that already left produced "sal a las 06:42" at 07:34.
  static bool dueNow(ScheduledTrip t, DateTime occ, DateTime now) {
    final leave = t.lastPlan != null && t.lastPlan!.occurrence == occ
        ? t.lastPlan!.leaveAt
        : ReminderTimes.fallbackLeave(occ, arriveBy: t.arriveBy);
    final ahead = leave.difference(now);
    return ahead <= refreshAhead && ahead >= -refreshGrace;
  }

  /// The live check: for every trip leaving within the next 40 minutes (or the one named by
  /// [tripId], when it is), plan again with real-time data from departures still ahead, tell the
  /// rider, and move the "leave now" reminder. Silent when nothing ahead still arrives in time.
  Future<int> refreshDue({required DateTime now, String? tripId}) async {
    final trips = repo.load();
    var refined = 0;
    final out = <ScheduledTrip>[];
    for (final t in trips) {
      final occ = t.enabled ? t.nextOccurrence(now) : null;
      final due = occ != null && (tripId == null || tripId == t.id) && dueNow(t, occ, now);
      if (!due) {
        out.add(t);
        continue;
      }
      final p = await plan(t, occ, now, notBefore: now.subtract(const Duration(minutes: 2)));
      if (p == null) {
        out.add(t);
        continue;
      }
      final trip = t.copyWith(lastPlan: p);
      out.add(trip);
      final link = tripLocation(trip, occ);
      await reminders.cancel(leaveId(t.id));
      await reminders.schedule(leaveId(t.id), l10n.tripLeaveTitle,
          l10n.tripLeaveBody(t.to.name, p.routesLabel, _hm(p.arriveAt)), p.leaveAt,
          payload: tripLocation(trip, occ, go: true));
      await reminders.show(refineId(t.id), l10n.tripRefineTitle(_hm(p.leaveAt)),
          l10n.tripRefineBody(p.routesLabel, _hm(p.arriveAt)), payload: link);
      refined++;
    }
    await repo.save(out);
    return refined;
  }
}

/// WorkManager / BGAppRefresh entry point: a headless isolate with no app state, so everything is
/// rebuilt from the preferences.
@pragma('vm:entry-point')
void tripRefreshDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('locale');
      final scheduler = TripScheduler(
        repo: ScheduledTripsRepository(prefs),
        api: HttpApiClient(AppConfig.apiUrl),
        reminders: const LocalReminderSink(),
        jobs: const WorkmanagerJobs(),
        locale: Locale(code == null || code.isEmpty || code == 'system' ? 'es' : code),
      );
      if (task == WorkmanagerJobs.alertTaskName) {
        final n = await runRouteAlertCheck(prefs: prefs, api: scheduler.api, locale: scheduler.locale, now: DateTime.now());
        debugPrint('route alerts poll: $n notification(s)');
        return true;
      }
      final n = await scheduler.refreshDue(now: DateTime.now(), tripId: inputData?['tripId']?.toString());
      debugPrint('trip refresh: $n reminder(s) refined');
      return true;
    } on MissingPluginException catch (e) {
      debugPrint('trip refresh: plugin missing in the background isolate: $e');
      return true;
    } catch (e) {
      debugPrint('trip refresh failed: $e');
      return false;
    }
  });
}
