library;

/// The guide, and the one card that points at it.
///
/// Asked for by TransMilenio against 1.16.0 (1.7). What this deliberately is *not* is a welcome
/// carousel: there is no account and nothing to set up, so the tests here are about a page that can
/// be read at any time and a pointer that disappears once.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/providers.dart';
import 'package:opentransit_mobile/features/help/guide_screen.dart';
import 'package:opentransit_mobile/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

City _city({bool realtime = true, bool fares = true}) => City.fromJson({
      'id': 'bogota',
      'name': 'Bogotá',
      'country': 'CO',
      'timezone': 'America/Bogota',
      'center': {'lat': 4.65, 'lon': -74.1},
      'bbox': [-74.3, 4.4, -73.9, 4.9],
      'features': {'realtimeVehicles': realtime, 'fares': fares},
    });

Future<ProviderContainer> _container(City city) async {
  SharedPreferences.setMockInitialValues({'city': 'bogota'});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [
    sharedPrefsProvider.overrideWithValue(prefs),
    cityProvider('bogota').overrideWith((ref) async => city),
  ]);
}

Widget _app(ProviderContainer c, Widget child) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the guide explains the app and names the city', (tester) async {
    final c = await _container(_city());
    addTearDown(c.dispose);
    await tester.pumpWidget(_app(c, const GuideScreen(cityId: 'bogota')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Cómo funciona'), findsOneWidget);
    expect(find.textContaining('Bogotá'), findsWidgets);
    expect(find.text('Viaje guiado'), findsOneWidget);
    expect(find.text('Sin conexión'), findsOneWidget);
    // No account, and the guide says so rather than leaving a rider looking for a sign-up.
    expect(find.textContaining('sin cuenta'), findsOneWidget);
  });

  testWidgets('a city without live vehicles is not promised them', (tester) async {
    final c = await _container(_city(realtime: false, fares: false));
    addTearDown(c.dispose);
    await tester.pumpWidget(_app(c, const GuideScreen(cityId: 'bogota')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Buses en vivo'), findsNothing);
    expect(find.text('Cuánto cuesta'), findsNothing);
    // The entries that hold everywhere are still there.
    expect(find.text('Planear un viaje'), findsOneWidget);
  });

  group('the first-open pointer', () {
    test('starts unseen and stays seen once dismissed', () async {
      SharedPreferences.setMockInitialValues({'city': 'bogota'});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
      addTearDown(c.dispose);

      expect(c.read(settingsProvider).guideSeen, isFalse);
      await c.read(settingsProvider.notifier).setGuideSeen(true);
      expect(c.read(settingsProvider).guideSeen, isTrue);
      // Written through, so the next launch does not show the card again.
      expect(prefs.getBool('guideSeen'), isTrue);
    });
  });
}
