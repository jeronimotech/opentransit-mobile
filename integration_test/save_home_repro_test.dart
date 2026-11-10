// Repro harness for "users can't save Casa/Trabajo". Drives the REAL app on a device:
// Favoritos → tap the empty "Casa" card → search a place → pick it → it must land in
// favoritesProvider as a home place and the card must fill. Run against prod:
//   flutter test integration_test/save_home_repro_test.dart -d <device> \
//     --dart-define=API_URL=https://api.opentransit.tech
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:opentransit_mobile/app.dart';
import 'package:opentransit_mobile/core/providers.dart';
import 'package:opentransit_mobile/core/storage/favorites.dart';
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

Future<bool> waitFor(WidgetTester tester, Finder finder, {int seconds = 30}) async {
  for (var i = 0; i < seconds * 5; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return true;
  }
  return false;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('save a place as Casa from Favoritos', (tester) async {
    loc.skipLocationPrompt = true;
    notif.skipNotificationPrompt = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final originalOnError = FlutterError.onError;
    FlutterError.onError = FlutterError.dumpErrorToConsole;
    addTearDown(() => FlutterError.onError = originalOnError);

    // Let the app pick MockApiClient via --dart-define=MOCK=true (offline, deterministic).
    final container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const OpenTransitApp(),
    ));
    await container.read(settingsProvider.notifier).setLocale(const Locale('es'));
    await settle(tester, 20);

    // Go through the real city picker, like the app's own screenshot run does,
    // so the shell is fully mounted before we deep-link.
    final pickedCity = await waitFor(tester, find.text('Bogotá'), seconds: 20);
    print('REPRO: city picker shown=$pickedCity');
    if (pickedCity) {
      await tester.tap(find.text('Bogotá'));
    }
    await waitFor(tester, find.byKey(const ValueKey('hub-plan')), seconds: 40);
    await settle(tester, 15);

    final router = container.read(routerProvider);
    router.go('/bogota/favorites');
    await settle(tester, 25);

    // The empty "Casa" quick place.
    final casa = find.byKey(const ValueKey('quick-home'));
    print('REPRO: quick-home present=${casa.evaluate().isNotEmpty}');
    expect(await waitFor(tester, casa), isTrue, reason: 'Favoritos should show the Casa card');
    await tester.tap(casa);
    await settle(tester, 20);

    // Now on the search screen (saveAs=home). Type a well-known public place.
    final field = find.byType(TextField).first;
    print('REPRO: on search, textfield present=${field.evaluate().isNotEmpty}');
    await tester.enterText(field, 'Portal Norte');
    await settle(tester, 30);
    final result0 = find.byKey(const ValueKey('result-0'));
    final gotResult = await waitFor(tester, result0, seconds: 30);
    print('REPRO: result-0 present=$gotResult');
    expect(gotResult, isTrue, reason: 'the geocoder should return at least one result');

    await tester.tap(result0);
    await settle(tester, 25);

    // Did it save?
    final favs = container.read(favoritesProvider);
    final homes = favs.where((f) => f.type == FavoriteType.place && f.kind == FavoriteKind.home).toList();
    print('REPRO: favorites after pick = ${favs.map((f) => '${f.type.name}/${f.kind.name}/${f.name}').toList()}');
    print('REPRO: home favorites = ${homes.length}');
    final reloaded = FavoritesRepository(await SharedPreferences.getInstance()).load();
    print('REPRO: reloaded-from-prefs homes = ${reloaded.where((f) => f.kind == FavoriteKind.home).length}');

    expect(homes, hasLength(1), reason: 'the picked place should be saved as Casa');
  });
}
