// Captures the trip map (route-coloured busesitos + faint full-route line) for
// a quick visual review. Bypasses the full walkthrough and goes straight to an
// itinerary detail.
//
//   flutter drive --driver=test_driver/integration_test.dart \
//       --target=integration_test/trip_map_shot_test.dart -d <device>
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

  testWidgets('trip map with busesitos and faint route', (tester) async {
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

    await tester.tap(find.text('Bogotá'));
    await settle(tester, 30);

    final router = container.read(routerProvider);
    final planner = container.read(plannerProvider.notifier);
    planner.setFrom(const Place(name: 'Portal Norte', position: LatLng(4.7546, -74.0459), stopId: 'bogota:PN'));
    planner.setTo(const Place(name: 'Portal Sur', position: LatLng(4.5978, -74.1616), stopId: 'bogota:PS'));
    await planner.plan('bogota');
    await settle(tester, 20);

    router.go('/bogota/results');
    await settle(tester, 30);
    expect(find.byType(ItineraryCard), findsWidgets);

    await tester.tap(find.byType(ItineraryCard).first);
    await settle(tester, 40);
    // Let the MapLibre platform view, the route shapes and the live buses settle.
    await Future<void>.delayed(const Duration(seconds: 8));
    await tester.pump();

    // ignore: avoid_print
    print('SCREENSHOT:trip_map');
    await Future<void>.delayed(const Duration(seconds: 4));
    await tester.pump();
  });
}
