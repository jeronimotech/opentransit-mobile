import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/api/mock_api_client.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/scheduling/push_registrar.dart';
import 'package:opentransit_mobile/core/storage/route_alerts_store.dart';
import 'package:opentransit_mobile/core/storage/scheduled_trips.dart';
import 'package:opentransit_mobile/core/utils/route_alerts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fixtures.dart';

const home = Place(name: 'Casa', position: LatLng(4.7420, -74.0930));
const work = Place(name: 'Trabajo', position: LatLng(4.6010, -74.0720));
final weekdays = {DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday, DateTime.friday};

ScheduledTrip _trip({String id = 't1', int hour = 8, Set<int>? days, DateTime? date, bool enabled = true, ScheduledTripPlan? plan}) =>
    ScheduledTrip(id: id, cityId: 'bogota', from: home, to: work, hour: hour, minute: 0,
        days: days ?? (date == null ? weekdays : const {}), date: date, enabled: enabled, lastPlan: plan);

void main() {
  final monday10 = DateTime(2026, 9, 14, 10);

  test('wake instants: twenty minutes before each departure within a week, planned or assumed', () {
    final planned = _trip(plan: ScheduledTripPlan(occurrence: DateTime(2026, 9, 15, 8), leaveAt: DateTime(2026, 9, 15, 7, 12),
        arriveAt: DateTime(2026, 9, 15, 7, 58), routes: const ['G30'], computedAt: monday10));
    final wakes = PushRegistrar.wakeInstants([planned], monday10);
    expect(wakes.first, DateTime(2026, 9, 15, 6, 52).toUtc());          // the planned occurrence
    expect(wakes[1], DateTime(2026, 9, 16, 8).subtract(const Duration(minutes: 65)).toUtc());   // assumed: 45 + 20 before
    expect(wakes.length, 5);                                              // Tue..Mon within 7 days: Tue Wed Thu Fri Mon
    expect(PushRegistrar.wakeInstants([_trip(enabled: false)], monday10), isEmpty);
    expect(PushRegistrar.wakeInstants([_trip(date: DateTime(2026, 9, 30))], monday10), isEmpty);   // beyond the horizon
  });

  test('the registration carries only the token, the instants and the routes', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = MockApiClient(bundle: DiskAssetBundle(), now: monday10, latency: Duration.zero);
    // Explicitly iOS: the registrar now reads the platform, and a test host reports Android.
    final reg = PushRegistrar(prefs: prefs, api: api, platform: 'ios');
    await reg.saveToken('AB' * 32, env: 'sandbox');
    await ScheduledTripsRepository(prefs).save([_trip()]);
    await RouteAlertsRepository(prefs).setSchedule('bogota', 'bogota:G30', AlertSchedule.always);
    await reg.sync(cityId: 'bogota', serverReminders: true, locale: const Locale('es'), now: monday10);
    final sent = api.pushRegistrations.single;
    expect(sent['token'], 'ab' * 32);
    expect(sent['env'], 'sandbox');
    expect(sent['routes'], ['bogota:G30']);
    expect((sent['wakeAt'] as List).length, 5);
    expect(sent.keys.toSet(), {'token', 'platform', 'env', 'locale', 'wakeAt', 'routes', 'cityId'});
    // unchanged → not sent again; a change → sent again; nothing left → unregistered
    await reg.sync(cityId: 'bogota', serverReminders: true, locale: const Locale('es'), now: monday10);
    expect(api.pushRegistrations.length, 1);
    await ScheduledTripsRepository(prefs).save([]);
    await RouteAlertsRepository(prefs).setSchedule('bogota', 'bogota:G30', AlertSchedule.never);
    await reg.sync(cityId: 'bogota', serverReminders: true, locale: const Locale('es'), now: monday10);
    expect(api.pushRegistrations, isEmpty);
  });

  test('without a token or with server reminders off nothing is sent', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = MockApiClient(bundle: DiskAssetBundle(), now: monday10, latency: Duration.zero);
    await ScheduledTripsRepository(prefs).save([_trip()]);
    final reg = PushRegistrar(prefs: prefs, api: api);
    await reg.sync(cityId: 'bogota', serverReminders: true, locale: const Locale('es'), now: monday10);
    await reg.saveToken('cd' * 32);
    await reg.sync(cityId: 'bogota', serverReminders: false, locale: const Locale('es'), now: monday10);
    expect(api.pushRegistrations, isEmpty);
  });

  test('the background alert poll notifies followed routes and records them', () async {
    SharedPreferences.setMockInitialValues({'city': 'bogota'});
    final prefs = await SharedPreferences.getInstance();
    final api = MockApiClient(bundle: DiskAssetBundle(), now: monday10, latency: Duration.zero);
    final alerts = await api.alerts('bogota');
    final route = alerts.expand((a) => a.routes).firstOrNull;
    expect(route, isNotNull, reason: 'the alerts fixture names at least one route');
    expect(await runRouteAlertCheck(prefs: prefs, api: api, locale: const Locale('es'), now: monday10), 0);
    await RouteAlertsRepository(prefs).setSchedule('bogota', route!.id, AlertSchedule.always);
    final n = await runRouteAlertCheck(prefs: prefs, api: api, locale: const Locale('es'), now: monday10);
    expect(n, greaterThan(0));
    // recorded: the same pass again notifies nothing
    expect(await runRouteAlertCheck(prefs: prefs, api: api, locale: const Locale('es'), now: monday10), 0);
  });

  // The server keeps one row per token, so it has to reach it byte for byte. APNs tokens are hex and
  // Apple hands them back in either case, which is why they are folded; an FCM token is mixed-case and
  // carries ':', '-' and '_', and folding one makes every push to that phone undeliverable.
  test('an Android registration keeps its token intact and says so', () async {
    const fcmToken = 'cXy7_d-Zk1M:APA91bH-Ab3Cd4Ef5Gh6Ij7Kl8Mn9Op0Qr1St2Uv3Wx4Yz';
    SharedPreferences.setMockInitialValues({'city': 'bogota'});
    final prefs = await SharedPreferences.getInstance();
    final api = MockApiClient(bundle: DiskAssetBundle(), now: monday10, latency: Duration.zero);
    final reg = PushRegistrar(prefs: prefs, api: api, platform: 'android');
    await reg.saveToken(fcmToken);
    expect(reg.token, fcmToken);
    await ScheduledTripsRepository(prefs).save([_trip()]);
    await reg.sync(cityId: 'bogota', serverReminders: true, locale: const Locale('es'), now: monday10);
    final sent = api.pushRegistrations.single;
    expect(sent['token'], fcmToken);
    expect(sent['platform'], 'android');
  });

  test('an iOS registration still folds its hex token to one case', () async {
    SharedPreferences.setMockInitialValues({'city': 'bogota'});
    final prefs = await SharedPreferences.getInstance();
    final api = MockApiClient(bundle: DiskAssetBundle(), now: monday10, latency: Duration.zero);
    final reg = PushRegistrar(prefs: prefs, api: api, platform: 'ios');
    await reg.saveToken('AB' * 32);
    expect(reg.token, 'ab' * 32);
    expect(reg.registration(cityId: 'bogota', trips: const [], routeIds: const [],
        locale: const Locale('es'), now: monday10)['platform'], 'ios');
  });
}
