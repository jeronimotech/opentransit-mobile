// Starts a trip and holds it running so a host script can background the app
// and photograph the Live Activity — the lock screen and the Dynamic Island
// are outside the Flutter view, so no in-app screenshot can show them.
//
//   flutter drive --driver=test_driver/integration_test.dart \
//       --target=integration_test/live_activity_shot_test.dart -d <device>
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:opentransit_mobile/app.dart';
import 'package:opentransit_mobile/core/api/mock_api_client.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/providers.dart';
import 'package:opentransit_mobile/core/utils/location.dart' as loc;
import 'package:opentransit_mobile/core/utils/notifications.dart' as notif;
import 'package:opentransit_mobile/features/planner/planner_state.dart';
import 'package:opentransit_mobile/features/planner/widgets/itinerary_card.dart';
import 'package:opentransit_mobile/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('hold a live activity', (tester) async {
    loc.skipLocationPrompt = true;
    notif.skipNotificationPrompt = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      apiClientProvider.overrideWithValue(MockApiClient()),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const OpenTransitApp(),
    ));
    final originalOnError = FlutterError.onError;
    FlutterError.onError = FlutterError.dumpErrorToConsole;
    addTearDown(() => FlutterError.onError = originalOnError);
    await container.read(settingsProvider.notifier).setLocale(const Locale('es'));
    await settle(tester, 20);

    final router = container.read(routerProvider);
    router.go('/bogota');
    await settle(tester, 30);
    final planner = container.read(plannerProvider.notifier);
    planner.setFrom(const Place(name: 'Portal Norte', position: LatLng(4.7546, -74.0459), stopId: 'bogota:PN'));
    planner.setTo(const Place(name: 'Portal Sur', position: LatLng(4.5978, -74.1616), stopId: 'bogota:PS'));
    router.go('/bogota/plan');
    await settle(tester, 15);
    await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
    await settle(tester, 30);
    await tester.tap(find.byType(ItineraryCard).first);
    await settle(tester, 30);
    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar viaje'));
    await settle(tester, 40);
    await Future<void>.delayed(const Duration(seconds: 4));
    expect(find.byKey(const ValueKey('go-stop')), findsOneWidget);

    // Cue the host, then keep the trip alive while it backgrounds the app and
    // takes the shots.
    debugPrint('LIVE_ACTIVITY_READY');
    for (var i = 0; i < 90; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pump();
    }
  });
}
