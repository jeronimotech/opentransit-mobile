// Regression for "new users can't save Casa/Trabajo": on a fresh install (no favorites,
// no recent trips) the Favoritos screen must still show the Casa/Trabajo cards — they are
// the way to *set* home and work. They used to be hidden behind an empty-state view.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/providers.dart';
import 'package:opentransit_mobile/features/favorites/favorites_screen.dart';
import 'package:opentransit_mobile/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('empty Favoritos still offers Casa and Trabajo', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        locale: Locale('es'),
        localizationsDelegates: [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        supportedLocales: AppLocalizations.supportedLocales,
        home: FavoritesScreen(cityId: 'bogota'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('quick-home')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-work')), findsOneWidget);
  });
}
