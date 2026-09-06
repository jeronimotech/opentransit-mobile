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
import 'package:opentransit_mobile/core/connectivity.dart';
import 'package:opentransit_mobile/core/providers.dart';
import 'package:opentransit_mobile/core/widgets/common.dart';
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
    await waitFor(tester, find.text('Cerca de ti'));
    await Future<void>.delayed(const Duration(seconds: 6)); // nearby boards + tiles
    await shot(tester, 'live_01_home');

    final router0 = container.read(routerProvider);
    // Street zoom at Calle 100: live layer on, ~dozens of buses, not thousands.
    router0.go('/bogota?lat=4.6837&lon=-74.0530&zoom=16.2');
    await settle(tester, 20);
    await Future<void>.delayed(const Duration(seconds: 10)); // SSE full frame (~1 MB)
    await shot(tester, 'live_02_home_zoom');
    router0.go('/bogota');
    await settle(tester, 10);

    final planner = container.read(plannerProvider.notifier);
    planner.setFrom(const Place(name: 'Portal Norte', position: LatLng(4.7546, -74.0459)));
    planner.setTo(const Place(name: 'Portal Sur', position: LatLng(4.5978, -74.1616)));
    final router = container.read(routerProvider);
    router.go('/bogota/plan');
    await settle(tester, 10);
    await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
    await waitFor(tester, find.byType(ItineraryCard), seconds: 60);
    await shot(tester, 'live_03_results');
    // Lote 1: scenario sections + countdowns on live data.
    expect(find.byKey(const ValueKey('results-scenarios')), findsOneWidget);
    expect(find.byKey(const ValueKey('scenario-fastest')), findsOneWidget);
    await shot(tester, 'live_lote1_01_results_scenarios');

    await tester.tap(find.byType(ItineraryCard).first);
    await settle(tester, 30);
    await Future<void>.delayed(const Duration(seconds: 4));
    await shot(tester, 'live_04_itinerary');
    // Lote 1: departure chips come from /stops/{id}/routes/{routeId}/next; pick the
    // second one when the API returned any.
    await tester.drag(find.byKey(const ValueKey('fare-block')), const Offset(0, -500));
    await settle(tester, 20);
    // Pick the last chip (the departure furthest from the plan's own), so the
    // itinerary visibly shifts; the re-timing rule itself is unit-tested.
    final depChips = find.byType(ChoiceChip);
    final n = depChips.evaluate().length;
    if (n >= 2) {
      await tester.ensureVisible(depChips.at(n - 1));
      await settle(tester, 10);
      await tester.tap(depChips.at(n - 1), warnIfMissed: false);
      await settle(tester, 20);
      // ignore: avoid_print
      print('LOTE1: departure chips=$n retimed=${find.byKey(const ValueKey('retimed-tag')).evaluate().isNotEmpty}');
    }
    await shot(tester, 'live_lote1_02_itinerary_departures');

    // Portal Norte station board (aggregated over its platforms)
    router.push('/bogota/stops/bogota:2000');
    await waitFor(tester, find.text('Próximos buses'));
    await Future<void>.delayed(const Duration(seconds: 4));
    await shot(tester, 'live_05_stop_board');
    expect(find.text('y en '), findsWidgets);
    await shot(tester, 'live_lote1_03_board_rows');
    container.read(connectionProvider.notifier).report(false);
    await settle(tester, 10);
    expect(find.byKey(const ValueKey('bar-offline')), findsOneWidget);
    await shot(tester, 'live_lote1_04_offline_bar');
    container.read(connectionProvider.notifier).report(true);
    await settle(tester, 10);
    await Future<void>.delayed(const Duration(seconds: 4));
    await settle(tester, 10);

    // Ubica tu bus: route G12 (bogota:12873) at stop bogota:2300
    router.push('/bogota/locate?stop=bogota:2300&route=bogota:12873');
    await waitFor(tester, find.text('Próximos buses'), seconds: 40);
    await waitFor(tester, find.textContaining('min'), seconds: 40);
    await Future<void>.delayed(const Duration(seconds: 5));
    await shot(tester, 'live_06_next_buses');

    // ── v1.2 shared bikes (needs the API's /rental/networks) ──
    final nets = await api.rentalNetworks('bogota');
    // ignore: avoid_print
    print('LIVE: rental networks=${nets.map((n) => '${n.name} up=${n.up} stations=${n.stations}').join('; ')}');
    if (nets.isEmpty || !city.bikeShareEnabled) {
      // ignore: avoid_print
      print('LIVE: bike share not available on this API yet — skipping bike screens');
    } else {
      final bikeOnly = await api.plan('bogota', const PlanRequest(
        from: Place(name: 'Parque de la 93', position: LatLng(4.6766, -74.0483)),
        to: Place(name: 'Calle 100', position: LatLng(4.6841, -74.0517)),
        modes: [TravelMode.walk, TravelMode.bikeRental],
      ));
      // ignore: avoid_print
      print('LIVE: bike-only 93→Calle 100: ${bikeOnly.itineraries.length} itineraries, rental legs ${bikeOnly.itineraries.map((i) => i.rentalLegList.length).toList()}, fare ${bikeOnly.itineraries.firstOrNull?.fare?.amount}');
      final mixed = await api.plan('bogota', const PlanRequest(
        from: Place(name: 'Chicó Norte', position: LatLng(4.6845, -74.0530)),
        to: Place(name: 'Portal Sur', position: LatLng(4.5978, -74.1616)),
        modes: [TravelMode.transit, TravelMode.walk, TravelMode.bikeRental],
      ));
      // ignore: avoid_print
      print('LIVE: bike+bus Chicó Norte→Portal Sur: ${mixed.itineraries.length} itineraries, with rental ${mixed.itineraries.where((i) => i.hasRental).length}, modes ${mixed.itineraries.map((i) => i.legs.map((l) => l.isRental ? 'RENTAL' : l.mode.wire).join('>')).toList()}');
      final near = await api.nearbyRentalStations('bogota', const LatLng(4.6766, -74.0483));
      // ignore: avoid_print
      print('LIVE: nearest stations ${near.map((s) => '${s.name} ${s.vehiclesAvailable}b/${s.docksAvailable}d ${s.distanceMeters}m').join('; ')}');

      // Bike-only plan in the UI.
      planner.setFrom(const Place(name: 'Parque de la 93', position: LatLng(4.6766, -74.0483)));
      planner.setTo(const Place(name: 'Calle 100 - Marketmedios', position: LatLng(4.6841, -74.0517)));
      planner.setModes({TravelMode.walk, TravelMode.bikeRental});
      router.go('/bogota/plan');
      await settle(tester, 10);
      expect(find.byKey(const ValueKey('mode-bikeShare')), findsOneWidget);
      await shot(tester, 'live_bike_01_plan_form');
      await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
      await waitFor(tester, find.byType(ItineraryCard), seconds: 60);
      await shot(tester, 'live_bike_02_results');
      await tester.tap(find.byType(ItineraryCard).first);
      await settle(tester, 30);
      await Future<void>.delayed(const Duration(seconds: 4));
      await shot(tester, 'live_bike_03_itinerary');

      // Bike + bus plan.
      planner.setFrom(const Place(name: 'Chicó Norte', position: LatLng(4.6845, -74.0530)));
      planner.setTo(const Place(name: 'Portal Sur', position: LatLng(4.5978, -74.1616)));
      planner.setModes({TravelMode.transit, TravelMode.walk, TravelMode.bikeRental});
      router.go('/bogota/plan');
      await settle(tester, 10);
      await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
      await waitFor(tester, find.byType(ItineraryCard), seconds: 60);
      await shot(tester, 'live_bike_04_results_mixed');
      final withRental = find.byType(ItineraryCard);
      await tester.tap(withRental.first);
      await settle(tester, 30);
      await Future<void>.delayed(const Duration(seconds: 4));
      await shot(tester, 'live_bike_05_itinerary_mixed');

      // Stations layer + sheet on the home map (Chapinero, street zoom).
      router.go('/bogota?lat=4.6766&lon=-74.0483&zoom=15.6');
      await settle(tester, 30);
      await Future<void>.delayed(const Duration(seconds: 8));
      await shot(tester, 'live_bike_06_home_stations');
      if (find.byKey(const ValueKey('nearby-rental')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const ValueKey('nearby-rental')));
        await settle(tester, 20);
        await Future<void>.delayed(const Duration(seconds: 2));
        await shot(tester, 'live_bike_07_station_sheet');
        router.pop();
      }
    }

    router.go('/bogota/settings');
    await settle(tester, 20);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('analytics-toggle')), 200, scrollable: find.byType(Scrollable).first);
    await settle(tester, 10);
    await shot(tester, 'live_lote1_05_settings_analytics');
    // Flush the walkthrough's events to the real API: 202 with `accepted`.
    await container.read(analyticsProvider).flush();
    expect(container.read(analyticsProvider).pending, isEmpty, reason: 'POST /events accepted the batch');

    router.go('/bogota/favorites');
    await settle(tester, 10);
    router.go('/bogota');
    await settle(tester, 20);

    // ── v1.4 taxi / ride-hailing (needs the API's /ondemand/providers) ──
    final odProviders = await api.onDemandProviders('bogota');
    // ignore: avoid_print
    print('LIVE: on-demand providers=${odProviders.map((p) => '${p.id}:${p.kind}:${p.estimateKind}').join('; ')}');
    if (odProviders.isEmpty || !city.onDemandEnabled) {
      // ignore: avoid_print
      print('LIVE: on-demand not available on this API yet — skipping taxi/app screens');
    } else {
      final est = await api.onDemandEstimate('bogota', const LatLng(4.7546, -74.0459), const LatLng(4.5978, -74.1616));
      // ignore: avoid_print
      print('LIVE: estimate Portal Norte→Portal Sur: ${est.distanceMeters} m / ${est.durationSeconds} s; ${est.estimates.map((e) => '${e.providerId}=${e.price?.amount ?? 'app'}').join(', ')}');
      final odPlan = await api.plan('bogota', const PlanRequest(
        from: Place(name: 'Portal Norte', position: LatLng(4.7546, -74.0459)),
        to: Place(name: 'Portal Sur', position: LatLng(4.5978, -74.1616)),
        modes: [TravelMode.transit, TravelMode.walk],
        onDemand: true,
        numItineraries: 6,
      ));
      // ignore: avoid_print
      print('LIVE: onDemand plan: ${odPlan.itineraries.length} itineraries, with ride ${odPlan.itineraries.where((i) => i.hasOnDemand).length}, modes ${odPlan.itineraries.map((i) => i.legs.map((l) => l.isOnDemand ? 'RIDE' : l.mode.wire).join('>')).toList()}');

      router.go('/bogota/plan');
      await settle(tester, 15);
      planner.setFrom(const Place(name: 'Portal Norte', position: LatLng(4.7546, -74.0459)));
      planner.setTo(const Place(name: 'Portal Sur', position: LatLng(4.5978, -74.1616)));
      planner.setModes({TravelMode.transit, TravelMode.walk});
      planner.setOnDemand(true);
      await settle(tester, 10);
      expect(find.byKey(const ValueKey('mode-onDemand')), findsOneWidget);
      await shot(tester, 'live_ondemand_01_plan_form');
      await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
      await settle(tester, 40);
      await shot(tester, 'live_ondemand_02_results');
      final rideCards = find.ancestor(of: find.byType(OnDemandChip), matching: find.byType(ItineraryCard));
      if (rideCards.evaluate().isNotEmpty) {
        await tester.tap(rideCards.first);
        await settle(tester, 30);
        await Future<void>.delayed(const Duration(seconds: 3));
        await tester.drag(find.byKey(const ValueKey('fare-block')), const Offset(0, -420));
        await settle(tester, 20);
        await shot(tester, 'live_ondemand_03_itinerary');
      } else {
        // ignore: avoid_print
        print('LIVE: no on-demand itinerary rendered for this pair');
      }
      router.go('/bogota/stops/bogota:2000');
      await settle(tester, 30);
      await shot(tester, 'live_ondemand_04_stop');
      planner.setOnDemand(false);
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
