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
import 'package:opentransit_mobile/core/storage/favorites.dart';
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
    await tester.tap(find.byKey(const ValueKey('sort-fewerTransfers')));
    await settle(tester, 10);
    await shot(tester, '06_results_sorted');

    await tester.tap(find.byType(ItineraryCard).first);
    await settle(tester, 30);
    await Future<void>.delayed(const Duration(seconds: 4));
    expect(find.byKey(const ValueKey('fare-block')), findsOneWidget);
    await shot(tester, '07_itinerary_fare');

    router.push('/bogota/stops/bogota:PN');
    await settle(tester, 30);
    // Board first: visible without scrolling, routes collapsed below it.
    expect(find.text('Próximos buses'), findsOneWidget);
    expect(find.byKey(const ValueKey('locate-from-stop')), findsOneWidget);
    expect(find.byKey(const ValueKey('routes-section')), findsOneWidget);
    await Future<void>.delayed(const Duration(seconds: 3));
    await shot(tester, '08_stop_board');

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

    await container.read(settingsProvider.notifier).setThemeMode(ThemeMode.dark);
    await container.read(settingsProvider.notifier).setPoiLayer(true);
    router.go('/bogota');
    await settle(tester, 30);
    await Future<void>.delayed(const Duration(seconds: 5));
    await shot(tester, '12_home_dark');
    await container.read(settingsProvider.notifier).setThemeMode(ThemeMode.light);
  }, timeout: const Timeout(Duration(minutes: 6)));
}
