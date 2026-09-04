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

/// Pumps until [finder] matches (real network: city + tiles can take a while).
Future<void> waitFor(WidgetTester tester, Finder finder, {int seconds = 30}) async {
  for (var i = 0; i < seconds * 5; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsWidgets);
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
    // v1.1 contract checks
    final city = await api.city('bogota');
    // ignore: avoid_print
    print('LIVE: fares=${city.fares?.base} ${city.fares?.currency} config.refresh=${city.config.departuresRefreshSeconds} components=${city.components.length} services=${city.services.length} links.pqrs=${city.links.pqrs != null}');
    final board = await api.board('bogota', 'bogota:2000');
    // ignore: avoid_print
    print('LIVE: board rows=${board.rows.length} first=${board.rows.firstOrNull?.route.shortName} next=${board.rows.firstOrNull?.next.map((t) => '${t.minutes}${t.realtime ? '*' : ''}')} stale=${board.freshness.stale}');
    final next = await api.nextBuses('bogota', 'bogota:2300', 'bogota:12873');
    // ignore: avoid_print
    print('LIVE: next ${next.route.shortName}@${next.stop.name}: ${next.next.map((n) => '${n.source}:${n.minutes}min').join(', ')}');
    final health = await api.health('bogota');
    // ignore: avoid_print
    print('LIVE: health stale=${health.realtime.isStale} age=${health.realtime.entityAgeP50Seconds} vehicles=${health.realtime.vehicles}');
    final pois = await api.pois('bogota', [-74.10, 4.60, -74.00, 4.80]);
    // ignore: avoid_print
    print('LIVE: pois=${pois.length}');

    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const OpenTransitApp()));
    await container.read(settingsProvider.notifier).setLocale(const Locale('es'));
    await settle(tester, 20);
    await waitFor(tester, find.text('Bogotá'));
    await tester.tap(find.text('Bogotá'));
    await waitFor(tester, find.text('¿Qué quieres consultar?'));
    await Future<void>.delayed(const Duration(seconds: 8)); // SSE full frame (~1 MB) + tiles
    await shot(tester, 'live_01_home');

    final planner = container.read(plannerProvider.notifier);
    planner.setFrom(const Place(name: 'Portal Norte', position: LatLng(4.7546, -74.0459)));
    planner.setTo(const Place(name: 'Portal Sur', position: LatLng(4.5978, -74.1616)));
    final router = container.read(routerProvider);
    router.go('/bogota/plan');
    await settle(tester, 10);
    await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
    await waitFor(tester, find.byType(ItineraryCard), seconds: 60);
    await shot(tester, 'live_02_results');

    await tester.tap(find.byType(ItineraryCard).first);
    await settle(tester, 30);
    await Future<void>.delayed(const Duration(seconds: 4));
    await shot(tester, 'live_03_itinerary');

    // Portal Norte station board (aggregated over its platforms)
    router.push('/bogota/stops/bogota:2000');
    await waitFor(tester, find.text('Próximos buses'));
    await Future<void>.delayed(const Duration(seconds: 4));
    await shot(tester, 'live_04_stop_board');

    // Ubica tu bus: route G12 (bogota:12873) at stop bogota:2300
    router.push('/bogota/locate?stop=bogota:2300&route=bogota:12873');
    await waitFor(tester, find.text('Próximos buses'), seconds: 40);
    await waitFor(tester, find.textContaining('min'), seconds: 40);
    await Future<void>.delayed(const Duration(seconds: 5));
    await shot(tester, 'live_05_next_buses');

    router.go('/bogota/favorites');
    await settle(tester, 10);
    router.go('/bogota');
    await settle(tester, 20);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
