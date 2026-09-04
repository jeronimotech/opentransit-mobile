// Walks through the main screens against the fixture-backed API so a host
// script can capture simulator screenshots. Each `SCREENSHOT:<name>` line
// printed to the log is a cue for `tool/screenshots.sh`.
//
//   flutter drive --driver=test_driver/integration_test.dart \
//       --target=integration_test/screenshots_test.dart -d <device>
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:opentransit_mobile/app.dart';
import 'package:opentransit_mobile/core/api/mock_api_client.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/providers.dart';
import 'package:opentransit_mobile/features/planner/planner_state.dart';
import 'package:opentransit_mobile/features/planner/widgets/itinerary_card.dart';
import 'package:opentransit_mobile/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _cue = Duration(seconds: 4);

Future<void> settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
}

Future<void> shot(WidgetTester tester, String name) async {
  await settle(tester);
  // ignore: avoid_print
  print('SCREENSHOT:$name');
  await Future<void>.delayed(_cue);
  await tester.pump();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('walk through the app', (tester) async {
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
    // Screenshots are taken in Spanish regardless of the simulator locale.
    await container.read(settingsProvider.notifier).setLocale(const Locale('es'));
    await settle(tester, 20);
    expect(find.text('Bogotá'), findsOneWidget);
    await shot(tester, '01_city_picker');

    await tester.tap(find.text('Bogotá'));
    await settle(tester, 30);
    expect(find.text('Paradas cercanas'), findsOneWidget);
    // Let tiles and the live stream arrive before the shot.
    await Future<void>.delayed(const Duration(seconds: 6));
    await shot(tester, '02_home_map');

    await tester.tap(find.text('¿A dónde vas?'));
    await settle(tester, 20);
    final planner = container.read(plannerProvider.notifier);
    planner.setFrom(const Place(name: 'Portal Norte', position: LatLng(4.7546, -74.0459), stopId: 'bogota:PN'));
    planner.setTo(const Place(name: 'Portal Sur', position: LatLng(4.5978, -74.1616), stopId: 'bogota:PS'));
    await settle(tester);
    await shot(tester, '03_plan_form');

    await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
    await settle(tester, 30);
    expect(find.byType(ItineraryCard), findsWidgets);
    await shot(tester, '04_results');

    await tester.tap(find.byType(ItineraryCard).first);
    await settle(tester, 30);
    await Future<void>.delayed(const Duration(seconds: 4));
    await shot(tester, '05_itinerary_detail');

    final router = container.read(routerProvider);
    router.push('/bogota/stops/bogota:PN');
    await settle(tester, 30);
    expect(find.text('Próximas salidas'), findsOneWidget);
    await Future<void>.delayed(const Duration(seconds: 3));
    await shot(tester, '06_stop_detail');

    router.push('/bogota/routes/bogota:B10');
    await settle(tester, 30);
    await Future<void>.delayed(const Duration(seconds: 3));
    await shot(tester, '07_route_detail');

    router.go('/bogota/alerts');
    await settle(tester, 20);
    await shot(tester, '08_alerts');

    await container.read(settingsProvider.notifier).setThemeMode(ThemeMode.dark);
    router.go('/bogota');
    await settle(tester, 30);
    await Future<void>.delayed(const Duration(seconds: 5));
    await shot(tester, '09_home_dark');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
