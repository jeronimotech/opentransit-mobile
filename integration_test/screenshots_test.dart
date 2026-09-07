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
import 'package:opentransit_mobile/core/connectivity.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/providers.dart';
import 'package:opentransit_mobile/core/storage/favorites.dart';
import 'package:opentransit_mobile/core/utils/location.dart' as loc;
import 'package:opentransit_mobile/core/utils/notifications.dart' as notif;
import 'package:opentransit_mobile/core/utils/rental.dart';
import 'package:opentransit_mobile/core/widgets/common.dart';
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
    // `flutter drive` reinstalls the app, resetting the simulator's location
    // authorisation; the system prompt would then cover every later shot.
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
    // Debug-only framework assertions (e.g. semantics parent-data checks that
    // fire while a MapLibre platform view is on screen) must not abort the
    // walkthrough: log them and keep going, like a release build would.
    final originalOnError = FlutterError.onError;
    FlutterError.onError = FlutterError.dumpErrorToConsole;
    addTearDown(() => FlutterError.onError = originalOnError);
    // Screenshots are taken in Spanish regardless of the simulator locale.
    await container.read(settingsProvider.notifier).setLocale(const Locale('es'));
    await settle(tester, 20);
    expect(find.text('Bogotá'), findsOneWidget);
    await shot(tester, '01_city_picker');

    await tester.tap(find.text('Bogotá'));
    await settle(tester, 30);
    // Map-first home: the sheet peeks with the three actions + "Cerca de ti".
    expect(find.text('Cerca de ti'), findsOneWidget);
    expect(find.byKey(const ValueKey('hub-plan')), findsOneWidget);
    expect(find.text('¿Qué quieres consultar?'), findsNothing);
    await Future<void>.delayed(const Duration(seconds: 5));
    await shot(tester, '02_home_map');

    // Drag the sheet up: shortcuts, recents and alerts appear.
    await tester.drag(find.text('Cerca de ti'), const Offset(0, -420));
    await settle(tester, 20);
    await Future<void>.delayed(const Duration(seconds: 2));
    await shot(tester, '03_home_sheet');
    await tester.drag(find.text('Cerca de ti'), const Offset(0, 420));
    await settle(tester, 20);

    final router = container.read(routerProvider);

    // Street zoom at Portal Norte: the live layer switches on (dots + bearing).
    router.go('/bogota?lat=4.7150&lon=-74.0500&zoom=16.1');
    await settle(tester, 30);
    await Future<void>.delayed(const Duration(seconds: 7));
    await shot(tester, '04_home_live_zoom');
    router.go('/bogota');
    await settle(tester, 10);

    // Ubica tu bus: Portal Norte → B10 → next buses (ETA-tinted map)
    router.push('/bogota/locate?stop=bogota:PN&route=bogota:B10');
    await settle(tester, 30);
    expect(find.text('Próximos buses'), findsOneWidget);
    await Future<void>.delayed(const Duration(seconds: 4));
    await shot(tester, '03_locate_bus');
    router.pop();
    await settle(tester, 10);

    await tester.tap(find.byKey(const ValueKey('hub-plan')));
    await settle(tester, 20);
    final planner = container.read(plannerProvider.notifier);
    planner.setFrom(const Place(name: 'Portal Norte', position: LatLng(4.7546, -74.0459), stopId: 'bogota:PN'));
    planner.setTo(const Place(name: 'Portal Sur', position: LatLng(4.5978, -74.1616), stopId: 'bogota:PS'));
    await settle(tester);
    // One time control, one mode row, advanced toggles behind "Más opciones".
    expect(find.byKey(const ValueKey('time-control')), findsOneWidget);
    expect(find.text('Salir a las'), findsNothing);
    expect(find.byKey(const ValueKey('more-options')), findsOneWidget);
    await shot(tester, '05_plan_form');

    await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
    await settle(tester, 30);
    expect(find.byType(ItineraryCard), findsWidgets);
    // Lote 1: results grouped by scenario with a leave-by countdown per card.
    expect(find.byKey(const ValueKey('results-scenarios')), findsOneWidget);
    expect(find.byKey(const ValueKey('scenario-fastest')), findsOneWidget);
    expect(find.byType(LeaveByLabel), findsWidgets);
    await shot(tester, 'lote1_01_results_scenarios');
    // The flat sorts moved into the "Ordenar" menu.
    await tester.tap(find.byKey(const ValueKey('sort-menu')));
    await settle(tester, 10);
    await tester.tap(find.byKey(const ValueKey('sort-fewerTransfers')));
    await settle(tester, 10);
    expect(find.byKey(const ValueKey('results-scenarios')), findsNothing);
    await shot(tester, '06_results_sorted');
    await tester.tap(find.byKey(const ValueKey('sort-menu')));
    await settle(tester, 10);
    await tester.tap(find.byKey(const ValueKey('sort-scenario')));
    await settle(tester, 10);

    await tester.tap(find.byType(ItineraryCard).first);
    await settle(tester, 30);
    await Future<void>.delayed(const Duration(seconds: 4));
    expect(find.byKey(const ValueKey('fare-block')), findsOneWidget);
    await shot(tester, '07_itinerary_fare');
    // Lote 1: live departure chips at the boarding stop; picking one re-times
    // the itinerary client-side ("Re-temporizado").
    expect(find.byKey(const ValueKey('retimed-tag')), findsNothing);
    // Pull the sheet up so the chips are on screen, then pick the second one.
    await tester.drag(find.byKey(const ValueKey('fare-block')), const Offset(0, -500));
    await settle(tester, 20);
    expect(find.text('Próximas salidas aquí'), findsWidgets);
    final depChip = find.byType(ChoiceChip).at(1);
    await tester.ensureVisible(depChip);
    await settle(tester, 10);
    await tester.tap(depChip);
    await settle(tester, 20);
    expect(find.byKey(const ValueKey('retimed-tag')), findsOneWidget);
    await shot(tester, 'lote1_02_itinerary_departures');

    router.push('/bogota/stops/bogota:PN');
    await settle(tester, 30);
    // Board first: visible without scrolling, routes collapsed below it.
    expect(find.text('Próximos buses'), findsOneWidget);
    expect(find.byKey(const ValueKey('locate-from-stop')), findsOneWidget);
    expect(find.byKey(const ValueKey('routes-section')), findsOneWidget);
    await Future<void>.delayed(const Duration(seconds: 3));
    await shot(tester, '08_stop_board');
    // Lote 1: Citymapper-style rows ("y en 13, 23 min") and the offline bar.
    expect(find.text('y en '), findsWidgets);
    await shot(tester, 'lote1_03_board_rows');
    container.read(connectionProvider.notifier).report(false);
    await settle(tester, 10);
    expect(find.byKey(const ValueKey('bar-offline')), findsOneWidget);
    await shot(tester, 'lote1_04_offline_bar');
    container.read(connectionProvider.notifier).report(true);
    await settle(tester, 10);
    expect(find.byKey(const ValueKey('bar-online')), findsOneWidget);
    await Future<void>.delayed(const Duration(seconds: 4));
    await settle(tester, 10);

    router.push('/bogota/routes/bogota:B10');
    await settle(tester, 30);
    await Future<void>.delayed(const Duration(seconds: 3));
    await shot(tester, '09_route_detail');

    // Favorites: Casa + a stop with its live board + a recent trip
    final favs = container.read(favoritesProvider.notifier);
    await favs.put(Favorite.place('bogota', const Place(name: 'Cra 45 # 174-20', position: LatLng(4.756, -74.044)), kind: FavoriteKind.home, icon: 'home', name: 'Casa'));
    await favs.put(Favorite.stop('bogota', const Stop(id: 'bogota:PN', name: 'Portal Norte', position: LatLng(4.7546, -74.0459), locationType: 'station', component: Component.trunk)));
    await favs.put(Favorite.route('bogota', const RouteRef(id: 'bogota:L10', shortName: 'L10', longName: 'TransMiCable Portal Tunal - Mirador', color: '#EF6C00', textColor: '#FFFFFF', mode: TravelMode.cableCar, agencyId: '7', component: Component.cable)));
    router.go('/bogota/favorites');
    await settle(tester, 30);
    await Future<void>.delayed(const Duration(seconds: 2));
    await shot(tester, '10_favorites');

    router.go('/bogota/alerts');
    await settle(tester, 20);
    await shot(tester, '11_alerts');

    // ── Lote 2 ──
    // Casa ⇄ Trabajo card: needs both ends saved, then it plans by itself.
    await favs.put(Favorite.place('bogota', const Place(name: 'Cl 57 Sur # 75-10', position: LatLng(4.5990, -74.1600)), kind: FavoriteKind.work, icon: 'work', name: 'Trabajo'));
    router.go('/bogota');
    await settle(tester, 30);
    await Future<void>.delayed(const Duration(seconds: 5));
    expect(find.byKey(const ValueKey('commute-card')), findsOneWidget);
    await shot(tester, 'lote2_01_commute_card');
    // Inverting swaps the direction by hand.
    await tester.tap(find.byKey(const ValueKey('commute-invert')));
    await settle(tester, 20);
    await Future<void>.delayed(const Duration(seconds: 3));
    await shot(tester, 'lote2_02_commute_inverted');

    // "Cuándo salir": the forecast timeline on the results screen.
    router.go('/bogota/plan');
    await settle(tester, 15);
    planner.setFrom(const Place(name: 'Portal Norte', position: LatLng(4.7546, -74.0459), stopId: 'bogota:PN'));
    planner.setTo(const Place(name: 'Portal Sur', position: LatLng(4.5978, -74.1616), stopId: 'bogota:PS'));
    planner.setModes({TravelMode.transit, TravelMode.walk});
    await settle(tester, 5);
    await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
    await settle(tester, 30);
    await tester.tap(find.byKey(const ValueKey('forecast-button')));
    await settle(tester, 30);
    expect(find.byKey(const ValueKey('forecast-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('forecast-recommended')), findsWidgets);
    await Future<void>.delayed(const Duration(seconds: 2));
    await shot(tester, 'lote2_03_when_to_leave');
    // Picking a departure closes the sheet and re-plans at that time.
    await tester.tap(find.byKey(const ValueKey('forecast-row-1')));
    await settle(tester, 30);
    expect(find.byKey(const ValueKey('forecast-list')), findsNothing);
    expect(container.read(plannerProvider).time, isNotNull);

    // Line page: live buses on the timeline and the "GO rápido" shortcut.
    router.push('/bogota/routes/bogota:B10');
    await settle(tester, 30);
    await Future<void>.delayed(const Duration(seconds: 4));
    expect(find.byKey(const ValueKey('route-live-count')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-go-0')), findsWidgets);
    await shot(tester, 'lote2_04_line_page');
    // Saved-route alerts: schedule menu on the same page.
    await tester.tap(find.byKey(const ValueKey('route-alerts-menu')));
    await settle(tester, 15);
    expect(find.byKey(const ValueKey('route-alert-weekdays')), findsOneWidget);
    await shot(tester, 'lote2_05_route_alerts');
    await tester.tap(find.byKey(const ValueKey('route-alert-weekdays')));
    await settle(tester, 15);
    router.pop();
    await settle(tester, 10);

    // ── Lote 3: GO ──
    router.go('/bogota/plan');
    await settle(tester, 15);
    await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
    await settle(tester, 30);
    await tester.tap(find.byType(ItineraryCard).first);
    await settle(tester, 30);
    // "Compartir en vivo" lives in the share menu on the itinerary.
    await tester.tap(find.byKey(const ValueKey('itinerary-share')));
    await settle(tester, 15);
    expect(find.byKey(const ValueKey('share-live')), findsOneWidget);
    await shot(tester, 'lote3_01_share_menu');
    Navigator.of(tester.element(find.byKey(const ValueKey('share-live')))).pop();
    await settle(tester, 15);
    // Start the trip: ongoing progress, current leg and the share button.
    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar viaje'));
    await settle(tester, 40);
    await Future<void>.delayed(const Duration(seconds: 4));
    expect(find.byKey(const ValueKey('go-stop')), findsOneWidget);
    expect(find.byKey(const ValueKey('go-share')), findsOneWidget);
    await shot(tester, 'lote3_02_go_in_progress');
    // Stopping shows the receipt.
    await tester.tap(find.byKey(const ValueKey('go-stop')));
    await settle(tester, 30);
    expect(find.byKey(const ValueKey('receipt-title')), findsOneWidget);
    await Future<void>.delayed(const Duration(seconds: 2));
    await shot(tester, 'lote3_03_receipt');
    await tester.tap(find.byKey(const ValueKey('receipt-close')));
    await settle(tester, 20);
    router.go('/bogota');
    await settle(tester, 10);

    // ── v1.2 shared bikes ──
    // Planner with "Bici pública" on (chip in the network colour).
    router.go('/bogota/plan');
    await settle(tester, 15);
    planner.setFrom(const Place(name: 'Parque de la 93', position: LatLng(4.6766, -74.0483)));
    planner.setTo(const Place(name: 'Calle 100 - Marketmedios', position: LatLng(4.6841, -74.0517)));
    await settle(tester, 5);
    await tester.tap(find.byKey(const ValueKey('mode-bikeShare')), warnIfMissed: false);
    await settle(tester, 10);
    if (!container.read(plannerProvider).modes.contains(TravelMode.bikeRental)) {
      // Fallback for flaky hit-testing on the platform view: same code path as the chip.
      planner.setModes(withBikeShare(container.read(plannerProvider).modes, on: true));
      await settle(tester, 5);
    }
    expect(container.read(plannerProvider).modes, contains(TravelMode.bikeRental));
    await shot(tester, 'bike_01_plan_form');

    await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
    await settle(tester, 30);
    // Rental itineraries come first; their cards carry the network chip.
    expect(find.byType(ItineraryCard), findsWidgets);
    expect(find.textContaining('Tembici'), findsWidgets);
    await shot(tester, 'bike_02_results');

    // Open the itinerary that carries the rental leg (its card shows the network chip).
    await tester.tap(find.ancestor(of: find.byType(RentalChip).first, matching: find.byType(ItineraryCard)).first);
    await settle(tester, 30);
    await Future<void>.delayed(const Duration(seconds: 3));
    // Pull the sheet up so the rental leg (pickup → ride → drop-off) is built and visible.
    await tester.drag(find.byKey(const ValueKey('fare-block')), const Offset(0, -420));
    await settle(tester, 20);
    expect(find.byKey(const ValueKey('rental-pickup')), findsOneWidget);
    expect(find.byKey(const ValueKey('rental-dropoff')), findsOneWidget);
    await shot(tester, 'bike_03_itinerary');

    // Home at street zoom in Chapinero: the stations layer with counts.
    // Leave the home branch first: returning to `/bogota` with new focus
    // params reuses the live HomeScreen, so the camera has to animate and the
    // nearby-station query only refreshes once the map settles.
    router.go('/bogota/favorites');
    await settle(tester, 15);
    router.go('/bogota?lat=4.6772&lon=-74.0500&zoom=15.6');
    await settle(tester, 40);
    await Future<void>.delayed(const Duration(seconds: 8));
    await settle(tester, 20);
    expect(find.byKey(const ValueKey('nearby-rental')), findsOneWidget);
    await shot(tester, 'bike_04_home_stations');

    // Station sheet via the "Cerca de ti" card. The card sits at the bottom of
    // the sheet's peek, so a blind tap lands a few pixels past its edge on some
    // devices; scroll it fully into view first, as a user would.
    await tester.ensureVisible(find.byKey(const ValueKey('nearby-rental')));
    await settle(tester, 10);
    await tester.tap(find.byKey(const ValueKey('nearby-rental')));
    await settle(tester, 20);
    expect(find.byKey(const ValueKey('rental-directions')), findsOneWidget);
    await shot(tester, 'bike_05_station_sheet');
    await tester.tap(find.byKey(const ValueKey('rental-directions')));
    await settle(tester, 15);
    router.go('/bogota');
    await settle(tester, 10);

    // ── v1.4 taxi / ride-hailing ──
    router.go('/bogota/plan');
    await settle(tester, 15);
    planner.setFrom(const Place(name: 'Cra 45 # 174-20', position: LatLng(4.7560, -74.0440)));
    planner.setTo(const Place(name: 'Cl 57 Sur # 75-10', position: LatLng(4.5990, -74.1600)));
    planner.setModes({TravelMode.transit, TravelMode.walk});
    await settle(tester, 5);
    await tester.tap(find.byKey(const ValueKey('mode-onDemand')), warnIfMissed: false);
    await settle(tester, 10);
    if (!container.read(plannerProvider).onDemand) {
      planner.setOnDemand(true); // same code path as the chip
      await settle(tester, 5);
    }
    expect(container.read(plannerProvider).onDemand, isTrue);
    await shot(tester, 'ondemand_01_plan_form');

    await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
    await settle(tester, 30);
    expect(find.byType(OnDemandChip), findsWidgets);
    await shot(tester, 'ondemand_02_results');

    // Open the direct ride (card with the taxi chip) and pull the sheet up to the picker.
    await tester.tap(find.ancestor(of: find.byType(OnDemandChip).first, matching: find.byType(ItineraryCard)).first);
    await settle(tester, 30);
    await Future<void>.delayed(const Duration(seconds: 3));
    await tester.drag(find.byKey(const ValueKey('fare-block')), const Offset(0, -420));
    await settle(tester, 20);
    expect(find.byKey(const ValueKey('ondemand-picker')), findsOneWidget);
    expect(find.byKey(const ValueKey('ondemand-request-taxi')), findsOneWidget);
    await shot(tester, 'ondemand_03_itinerary');

    // Stop page: "Llegar en taxi / app" secondary action.
    router.go('/bogota/stops/bogota:PN');
    await settle(tester, 30);
    expect(find.byKey(const ValueKey('stop-ondemand')), findsOneWidget);
    await shot(tester, 'ondemand_04_stop');
    planner.setOnDemand(false);
    router.go('/bogota');
    await settle(tester, 10);

    // Lote 1: privacy section with the anonymous-statistics toggle.
    router.go('/bogota/settings');
    await settle(tester, 20);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('analytics-toggle')), 200, scrollable: find.byType(Scrollable).first);
    await settle(tester, 10);
    expect(find.byKey(const ValueKey('analytics-clear')), findsOneWidget);
    await shot(tester, 'lote1_05_settings_analytics');
    expect(container.read(analyticsProvider).pending, isNotEmpty, reason: 'events were tracked during the walkthrough');

    // v1.9 "Cerca de mí": the live map centred on the user.
    router.go('/bogota/live');
    await settle(tester, 40);
    await Future<void>.delayed(const Duration(seconds: 3));
    await settle(tester, 20);
    await shot(tester, 'nearme_01_map');

    // The full list, sheet pulled up.
    await tester.drag(find.byKey(const ValueKey('near-radius-600')), const Offset(0, -360));
    await settle(tester, 25);
    await shot(tester, 'nearme_02_list');

    // Selecting a bus: open its detail from the row, then come back to the map
    // with that bus highlighted and its route drawn faintly.
    final row = find.byWidgetPredicate(
      (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('near-row-'),
    );
    if (row.evaluate().isNotEmpty) {
      await tester.tap(row.first);
      await settle(tester, 35);
      router.pop();
      await settle(tester, 35);
      // Drop the sheet back to peek: the point of "selected" is the highlighted
      // bus and its faint route on the map, and a raised sheet hides both.
      await tester.drag(find.byKey(const ValueKey('near-radius-600')), const Offset(0, 420));
      await settle(tester, 25);
      await Future<void>.delayed(const Duration(seconds: 2));
      await settle(tester, 15);
    }
    await shot(tester, 'nearme_03_selected');

    // Back to me: the pill appears because selecting a bus moved the camera.
    final recentre = find.byKey(const ValueKey('near-recentre'));
    if (recentre.evaluate().isNotEmpty) {
      await tester.tap(recentre);
      await settle(tester, 20);
    }

    // Empty state: filter to a component with nothing around, and show the
    // one-tap widen. Asserted, not hoped for — a shot named "empty" that is not
    // empty is worse than no shot.
    final cableChip = find.byKey(const ValueKey('near-comp-cable'));
    await tester.ensureVisible(cableChip);
    await settle(tester, 8);
    await tester.tap(cableChip);
    await settle(tester, 25);
    expect(find.byKey(const ValueKey('near-widen')), findsOneWidget,
        reason: 'the cable filter should leave nothing nearby, showing the empty state');
    await shot(tester, 'nearme_04_empty');
    await tester.tap(cableChip); // back to "all" for the shots that follow
    await settle(tester, 12);
    router.go('/bogota');
    await settle(tester, 15);

    // v2.0 assistant, phase 1 (text). The entry point lives inside the search
    // pill and in the action row; both open the same sheet.
    router.go('/bogota');
    await settle(tester, 25);
    await tester.tap(find.byKey(const ValueKey('search-ask')));
    await settle(tester, 25);
    // First open: the suggested prompts and the one-time provider notice.
    expect(find.byKey(const ValueKey('assistant-notice')), findsOneWidget);
    expect(find.byKey(const ValueKey('assistant-suggestion-0')), findsOneWidget);
    await shot(tester, 'chat_01_intro');

    // A trip question: the tool line, then the itinerary card, then the prose.
    await tester.tap(find.byKey(const ValueKey('assistant-suggestion-0')));
    await settle(tester, 60);
    await Future<void>.delayed(const Duration(seconds: 2));
    await settle(tester, 20);
    expect(find.byType(ItineraryCard), findsWidgets,
        reason: 'the card lands before the prose, drawn with the real widget');
    expect(find.byKey(const ValueKey('assistant-notice')), findsNothing,
        reason: 'the notice is shown once per session');
    await shot(tester, 'chat_02_trip');

    // The card is not a dead end: tapping it opens the results screen.
    await tester.tap(find.byType(ItineraryCard).first);
    await settle(tester, 45);
    await Future<void>.delayed(const Duration(seconds: 2));
    await settle(tester, 20);
    await shot(tester, 'chat_03_card_tap');
    router.go('/bogota');
    await settle(tester, 20);

    // A refusal reads as one plain sentence, never as an error code.
    await tester.tap(find.byKey(const ValueKey('search-ask')));
    await settle(tester, 25);
    await tester.enterText(find.byKey(const ValueKey('assistant-input')), 'provoca un error');
    await settle(tester, 10);
    await tester.tap(find.byKey(const ValueKey('assistant-send')));
    await settle(tester, 30);
    expect(find.byKey(const ValueKey('assistant-error')), findsOneWidget);
    await shot(tester, 'chat_04_error');

    // Starting over: confirm first, then the thread is gone and the suggestions
    // are back. The session id changes too, so the reply quota starts fresh.
    await tester.tap(find.byKey(const ValueKey('assistant-new')));
    await settle(tester, 20);
    expect(find.byKey(const ValueKey('assistant-new-confirm')), findsOneWidget);
    await tester.tap(find.text('Empezar de nuevo'));
    await settle(tester, 20);
    expect(find.byKey(const ValueKey('assistant-suggestion-0')), findsOneWidget);
    await shot(tester, 'chat_05_new_conversation');

    // The sheet is a modal route: close it from its own button, not the router.
    await tester.tap(find.byIcon(Icons.close_rounded));
    await settle(tester, 20);

    await container.read(settingsProvider.notifier).setThemeMode(ThemeMode.dark);
    await container.read(settingsProvider.notifier).setPoiLayer(true);
    router.go('/bogota');
    await settle(tester, 30);
    await Future<void>.delayed(const Duration(seconds: 5));
    await shot(tester, '12_home_dark');
    await container.read(settingsProvider.notifier).setThemeMode(ThemeMode.light);
  }, timeout: const Timeout(Duration(minutes: 16)));
}
