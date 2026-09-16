// Diagnostic: schedule a trip through the real providers on the simulator and ask iOS which local
// notifications are actually pending. Run:
//   flutter test integration_test/reminders_live_test.dart -d <simulator> --dart-define=API_URL=https://api.opentransit.tech
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:opentransit_mobile/app.dart';
import 'package:opentransit_mobile/core/api/http_api_client.dart';
import 'package:opentransit_mobile/core/config.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/providers.dart';
import 'package:opentransit_mobile/core/utils/location.dart' as loc;
import 'package:opentransit_mobile/core/utils/notifications.dart' as notif;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('scheduling a trip leaves reminders pending in iOS', (tester) async {
    loc.skipLocationPrompt = true;
    notif.skipNotificationPrompt = true;
    SharedPreferences.setMockInitialValues({'city': 'bogota'});
    final prefs = await SharedPreferences.getInstance();
    final api = HttpApiClient(AppConfig.apiUrl);
    final container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      apiClientProvider.overrideWithValue(api),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const OpenTransitApp()));
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pump();
    }
    final ok = await notif.LocalNotifications.instance.init();
    // ignore: avoid_print
    print('LIVE: notifications init=$ok');

    final now = DateTime.now();
    final target = now.add(const Duration(hours: 3));
    final trip = ScheduledTrip(
      id: 'diag', cityId: 'bogota',
      from: const Place(name: 'Casa', position: LatLng(4.7420, -74.0930)),
      to: const Place(name: 'Trabajo', position: LatLng(4.6010, -74.0720)),
      hour: target.hour, minute: target.minute, arriveBy: true,
      date: DateTime(target.year, target.month, target.day), createdAt: now,
    );
    await container.read(scheduledTripsProvider.notifier).add(trip);
    final stored = container.read(scheduledTripsProvider).single;
    // ignore: avoid_print
    print('LIVE: stored plan leaveAt=${stored.lastPlan?.leaveAt} arriveAt=${stored.lastPlan?.arriveAt} routes=${stored.lastPlan?.routes}');

    // direct probes: what does the helper answer, and what does the plugin say when asked directly?
    final probe = await notif.LocalNotifications.instance.schedule(777, 'probe', 'probe body', now.add(const Duration(minutes: 5)), payload: '/bogota');
    // ignore: avoid_print
    print('LIVE: helper schedule() returned $probe');
    try {
      await FlutterLocalNotificationsPlugin().zonedSchedule(
        id: 778, title: 'raw', body: 'raw body',
        scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(minutes: 6)),
        notificationDetails: const NotificationDetails(iOS: DarwinNotificationDetails(presentAlert: true)),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      // ignore: avoid_print
      print('LIVE: raw zonedSchedule ok · tz.local=${tz.local.name}');
    } catch (e) {
      // ignore: avoid_print
      print('LIVE: raw zonedSchedule threw: $e');
    }
    final settings = await FlutterLocalNotificationsPlugin().resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.checkPermissions();
    // ignore: avoid_print
    print('LIVE: iOS permissions enabled=${settings?.isEnabled} alert=${settings?.isAlertEnabled}');
    final pending = await FlutterLocalNotificationsPlugin().pendingNotificationRequests();
    for (final p in pending) {
      // ignore: avoid_print
      print('LIVE: pending id=${p.id} title="${p.title}" body="${p.body}" payload=${p.payload}');
    }
    // ignore: avoid_print
    print('LIVE: pending count=${pending.length}');
    expect(pending.where((p) => p.id >= 1000000), isNotEmpty);
    await container.read(scheduledTripsProvider.notifier).remove('diag');
  });
}
