// Smoke test against a running opentransit-api (default http://localhost:8001,
// override with --dart-define=API_URL=...). Plans Portal Norte → Portal Sur
// with live Bogotá data and prints `SCREENSHOT:` cues like screenshots_test.
//
//   tool/screenshots.sh <device> integration_test/live_api_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:opentransit_mobile/app.dart';
import 'package:opentransit_mobile/core/api/http_api_client.dart';
import 'package:opentransit_mobile/core/config.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/providers.dart';
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

Future<void> shot(WidgetTester tester, String name) async {
  await settle(tester);
  // ignore: avoid_print
  print('SCREENSHOT:$name');
  await Future<void>.delayed(const Duration(seconds: 4));
  await tester.pump();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('live API: plan Portal Norte → Portal Sur', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = HttpApiClient(AppConfig.apiUrl);
    final container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      apiClientProvider.overrideWithValue(api),
    ]);
    addTearDown(container.dispose);

    // Contract checks straight against the API before touching the UI.
    final cities = await api.cities();
    expect(cities.map((c) => c.id), contains('bogota'));
    final plan = await api.plan('bogota', const PlanRequest(
      from: Place(name: 'Portal Norte', position: LatLng(4.7546, -74.0459)),
      to: Place(name: 'Portal Sur', position: LatLng(4.5978, -74.1616)),
    ));
    // ignore: avoid_print
    print('LIVE: ${plan.itineraries.length} itineraries, router ${plan.routerEngine} ${plan.routerVersion}, warnings ${plan.warnings}');
    expect(plan.itineraries, isNotEmpty);
    final frame = await api.vehicles('bogota');
    // ignore: avoid_print
    print('LIVE: ${frame.count} vehicles, p50 age ${frame.health.entityAgeP50Seconds}s');
    final alerts = await api.alerts('bogota');
    // ignore: avoid_print
    print('LIVE: ${alerts.length} alerts');

    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const OpenTransitApp()));
    await container.read(settingsProvider.notifier).setLocale(const Locale('es'));
    await settle(tester, 20);
    await tester.tap(find.text('Bogotá'));
    await settle(tester, 30);
    expect(find.text('Paradas cercanas'), findsOneWidget);
    await Future<void>.delayed(const Duration(seconds: 8)); // SSE full frame (~1 MB) + tiles
    await shot(tester, 'live_01_home');

    final planner = container.read(plannerProvider.notifier);
    planner.setFrom(const Place(name: 'Portal Norte', position: LatLng(4.7546, -74.0459)));
    planner.setTo(const Place(name: 'Portal Sur', position: LatLng(4.5978, -74.1616)));
    final router = container.read(routerProvider);
    router.go('/bogota/plan');
    await settle(tester, 10);
    await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
    await settle(tester, 60);
    expect(find.byType(ItineraryCard), findsWidgets);
    await shot(tester, 'live_02_results');

    await tester.tap(find.byType(ItineraryCard).first);
    await settle(tester, 30);
    await Future<void>.delayed(const Duration(seconds: 4));
    await shot(tester, 'live_03_itinerary');

    final stopId = plan.itineraries.first.legs.firstWhere((l) => l.transit).from.stopId!;
    router.push('/bogota/stops/${Uri.encodeComponent(stopId)}');
    await settle(tester, 40);
    expect(find.text('Próximas salidas'), findsOneWidget);
    await Future<void>.delayed(const Duration(seconds: 3));
    await shot(tester, 'live_04_stop');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
