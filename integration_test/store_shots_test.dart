// Store-listing walkthrough: six screens that tell the app's story, driven
// against the *production* API so the shots carry real Bogotá data.
//
//   tool/screenshots.sh <device-udid> integration_test/store_shots_test.dart \
//       --dart-define=API_URL=https://api.opentransit.tech \
//       --dart-define=SHOT_LOCALE=es
//
// The locale comes from `SHOT_LOCALE` (`es` or `en`) and is applied through the
// app's own settings, so the run does not depend on the simulator's language
// for the *app* strings (we still set the simulator language so the status bar
// and any system chrome match).
//
// Every step is driven by widget keys or the router — never by localised
// strings — so the same file produces both language sets.
import 'package:flutter/material.dart';
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
import 'package:opentransit_mobile/features/planner/planner_state.dart';
import 'package:opentransit_mobile/features/planner/widgets/itinerary_card.dart';
import 'package:opentransit_mobile/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `es` (default) or `en`.
const shotLocale = String.fromEnvironment('SHOT_LOCALE', defaultValue: 'es');

/// Public landmarks only — no personal addresses ever land in a store shot.
const _from = Place(
  name: 'Av. Carrera 7 # 32-16',
  position: LatLng(4.6285, -74.0665),
);
const _to = Place(name: 'Portal Norte', position: LatLng(4.7546, -74.0459));

Future<void> settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
}

Future<void> waitFor(WidgetTester tester, Finder finder, {int seconds = 30}) async {
  for (var i = 0; i < seconds * 5; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsWidgets);
}

/// Holds the frame still, prints the cue `tool/screenshots.sh` greps for, then
/// keeps pumping while the host grabs the PNG.
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

  testWidgets('store listing walkthrough ($shotLocale)', (tester) async {
    loc.skipLocationPrompt = true;
    notif.skipNotificationPrompt = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    // Live data occasionally trips debug-only framework assertions (semantics
    // over the MapLibre platform view); log them like a release build would
    // instead of aborting a multi-minute capture run.
    final originalOnError = FlutterError.onError;
    FlutterError.onError = FlutterError.dumpErrorToConsole;
    addTearDown(() => FlutterError.onError = originalOnError);

    final api = HttpApiClient(AppConfig.apiUrl);
    final container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      apiClientProvider.overrideWithValue(api),
    ]);
    addTearDown(container.dispose);

    // Prove we are really on the production feed before spending 5 minutes.
    final frame = await api.vehicles('bogota');
    // ignore: avoid_print
    print('STORE: api=${AppConfig.apiUrl} locale=$shotLocale vehicles=${frame.count}');

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const OpenTransitApp(),
    ));
    await container.read(settingsProvider.notifier).setLocale(const Locale(shotLocale));
    await settle(tester, 20);

    await waitFor(tester, find.text('Bogotá'));
    await tester.tap(find.text('Bogotá'));
    await waitFor(tester, find.byKey(const ValueKey('hub-plan')), seconds: 40);
    await Future<void>.delayed(const Duration(seconds: 8)); // tiles + nearby boards
    final router = container.read(routerProvider);

    // 1 ── Map-first home. Pushed to street-ish zoom (≥ 14) so the live fleet
    // layer is on: the map is the product, the sheet only peeks.
    router.go('/bogota?lat=4.6837&lon=-74.0530&zoom=14.8');
    await settle(tester, 30);
    await Future<void>.delayed(const Duration(seconds: 12)); // camera + SSE frame
    await settle(tester, 20);
    await shot(tester, '01_home_map');

    // 2 ── Planning a trip from an address.
    final planner = container.read(plannerProvider.notifier);
    planner.setFrom(_from);
    planner.setTo(_to);
    planner.setModes({TravelMode.transit, TravelMode.walk});
    router.go('/bogota/plan');
    await settle(tester, 25);
    await Future<void>.delayed(const Duration(seconds: 2));
    await shot(tester, '02_plan_from_address');

    // 3 ── Results. Driven through the notifier rather than the localised CTA.
    final plan = await planner.plan('bogota');
    // ignore: avoid_print
    print('STORE: ${plan?.itineraries.length} itineraries for ${_from.name} → ${_to.name}');
    router.push('/bogota/results');
    await waitFor(tester, find.byType(ItineraryCard), seconds: 60);
    await Future<void>.delayed(const Duration(seconds: 3));
    await shot(tester, '03_results');

    // 4 ── The itinerary itself, with the live buses drawn on its map.
    await tester.tap(find.byType(ItineraryCard).first);
    await settle(tester, 40);
    await Future<void>.delayed(const Duration(seconds: 8));
    await settle(tester, 20);
    await shot(tester, '04_itinerary_live');

    // 5 ── "Cerca de mí" / "Near me": the live map centred on the user.
    router.go('/bogota/live');
    await settle(tester, 45);
    await Future<void>.delayed(const Duration(seconds: 10));
    await settle(tester, 25);
    final nearRows = find.byWidgetPredicate(
      (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('near-row-'),
    );
    // ignore: avoid_print
    print('STORE: near-me rows=${nearRows.evaluate().length}');
    await shot(tester, '05_near_me');

    // 6 ── "Ubica tu bus" / "Locate your bus": route G12 at stop bogota:2300.
    router.go('/bogota');
    await settle(tester, 15);
    router.push('/bogota/locate?stop=bogota:2300&route=bogota:12873');
    await settle(tester, 45);
    await Future<void>.delayed(const Duration(seconds: 10));
    await settle(tester, 25);
    await shot(tester, '06_locate_bus');
  }, timeout: const Timeout(Duration(minutes: 12)));
}
