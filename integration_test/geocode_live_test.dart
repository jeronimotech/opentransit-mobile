// Search against the real API from the app's own search screen: a Bogotá address resolves through the
// city's cadastral geocoder, a neighbourhood through the cadastre's polygons (v2.2). Run:
//   flutter test integration_test/geocode_live_test.dart -d <simulator> --dart-define=API_URL=https://api.opentransit.tech
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:opentransit_mobile/app.dart';
import 'package:opentransit_mobile/core/api/http_api_client.dart';
import 'package:opentransit_mobile/core/config.dart';
import 'package:opentransit_mobile/core/providers.dart';
import 'package:opentransit_mobile/core/utils/location.dart' as loc;
import 'package:opentransit_mobile/core/utils/notifications.dart' as notif;
import 'package:opentransit_mobile/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('live API: addresses and neighbourhoods from the search screen', (tester) async {
    loc.skipLocationPrompt = true;
    notif.skipNotificationPrompt = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    FlutterError.onError = FlutterError.dumpErrorToConsole;
    final api = HttpApiClient(AppConfig.apiUrl);
    final container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      apiClientProvider.overrideWithValue(api),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const OpenTransitApp()));
    await container.read(settingsProvider.notifier).setLocale(const Locale('es'));
    await settle(tester, 20);
    await waitFor(tester, find.text('Bogotá'));
    final router = container.read(routerProvider);

    Future<void> search(String q, String expectName, String expectLabelPart) async {
      router.go('/bogota/search?field=to');
      await settle(tester, 15);
      final field = find.byType(TextField).first;
      await tester.enterText(field, q);
      // the list refreshes after the debounce and the network round trip: wait for the expected first
      // result instead of asserting on whatever the previous query left on screen
      final first = find.descendant(of: find.byKey(const ValueKey('result-0')), matching: find.text(expectName));
      await waitFor(tester, first, seconds: 30);
      await settle(tester, 5);
      expect(first, findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('result-0')), matching: find.textContaining(expectLabelPart)), findsOneWidget);
      // ignore: avoid_print
      print('LIVE: "$q" → $expectName · $expectLabelPart ✓');
      // hold the list on screen so a screenshot can be taken from outside
      await settle(tester, 60);
    }

    await search('Cra 7 # 72-41', 'Carrera 7 # 72-41', 'Porciuncula');
    await search('Calle 127 con Carrera 7', 'Avenida Calle 127 # 7-20', 'Bella Suiza');
    await search('Cedritos', 'Cedritos', 'Barrio · Usaquen');
    await search('Clínica Shaio', 'Fundación Clínica Shaio', 'Parada');
  });
}
