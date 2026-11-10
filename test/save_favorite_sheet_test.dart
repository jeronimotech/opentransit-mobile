// Repro for "users can't save Casa/Trabajo": open the save sheet, pick Casa, tap Guardar,
// and the favorite must land in favoritesProvider as a home place.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/analytics/analytics.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/providers.dart';
import 'package:opentransit_mobile/core/storage/favorites.dart';
import 'package:opentransit_mobile/features/favorites/save_favorite_sheet.dart';
import 'package:opentransit_mobile/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoopTransport implements AnalyticsTransport {
  @override
  Future<int> send(String cityId, Map<String, dynamic> batch) async => 200;
}

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      // Real Analytics starts a periodic flush timer in its constructor, which the
      // testWidgets binding flags as a leaked timer. Use one without the timer.
      analyticsProvider.overrideWith((ref) => Analytics(
            prefs: prefs,
            transport: _NoopTransport(),
            cityId: () => 'bogota',
            autoFlush: false,
          )),
    ]);
  });
  tearDown(() => container.dispose());

  Widget host(Widget child) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      );

  testWidgets('saving a place as Casa stores a home favorite', (tester) async {
    const place = Place(name: 'Mi casa', position: LatLng(4.7420, -74.0930));
    await tester.pumpWidget(host(Consumer(builder: (context, ref, _) => TextButton(
          key: const ValueKey('open'),
          onPressed: () => showSaveFavoriteSheet(context, ref, 'bogota', place),
          child: const Text('open'),
        ))));
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();

    // Pick "Casa" then tap "Guardar favorito".
    await tester.tap(find.text('Casa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar favorito'));
    await tester.pumpAndSettle();

    final favs = container.read(favoritesProvider);
    expect(favs, hasLength(1), reason: 'the place should have been saved');
    expect(favs.single.kind, FavoriteKind.home);
    // and it must survive a reload from prefs
    final reloaded = FavoritesRepository(await SharedPreferences.getInstance()).load();
    expect(reloaded.where((f) => f.kind == FavoriteKind.home), hasLength(1));
  });
}
