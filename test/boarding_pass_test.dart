library;

/// The boarding card.
///
/// Asked for by TransMilenio against 1.16.0 (1.3): the code, the destination written on the bus,
/// where to wait and where to get off were spread across the leg detail, and the guided trip never
/// showed the destination — the one thing a rider compares against the vehicle in front of them.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/providers.dart';
import 'package:opentransit_mobile/features/planner/widgets/boarding_pass.dart';
import 'package:opentransit_mobile/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/factories.dart';

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({'city': 'bogota'});
  final prefs = await SharedPreferences.getInstance();
  // No city lookup: the card needs none, and the real client would leave a connection timer
  // pending past the end of the test.
  return ProviderContainer(overrides: [
    sharedPrefsProvider.overrideWithValue(prefs),
    currentCityProvider.overrideWithValue(null),
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
        home: Scaffold(body: child),
      ),
    );

Leg _trunkLeg({String? headsign = 'Portal Sur', String? code = 'L067'}) => leg(
      mode: TravelMode.bus,
      transit: true,
      route: routeRef(id: 'bogota:B74', shortName: 'B74'),
      fromName: 'San Victorino C - 4 ó 6',
      toName: 'Av Chile',
      fromCode: code,
      toCode: '142A00',
      headsign: headsign,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the card carries the code, the destination, where to wait and where to get off',
      (tester) async {
    final c = await _container();
    addTearDown(c.dispose);
    await tester.pumpWidget(_app(c, BoardingPass(cityId: 'bogota', leg: _trunkLeg())));
    await tester.pump();

    expect(find.text('B74'), findsWidgets);
    expect(find.text('Destino que se lee en el bus'), findsOneWidget);
    expect(find.text('Portal Sur'), findsOneWidget);
    // The platform is part of where to wait: at a trunk station the stop name alone is not enough.
    expect(find.text('San Victorino C - 4 ó 6 · L067'), findsOneWidget);
    expect(find.text('Av Chile · 142A00'), findsOneWidget);
  });

  testWidgets('a feed without a headsign falls back to the route name rather than an empty field',
      (tester) async {
    final c = await _container();
    addTearDown(c.dispose);
    await tester.pumpWidget(_app(
        c,
        BoardingPass(
            cityId: 'bogota',
            leg: leg(
              mode: TravelMode.bus,
              transit: true,
              route: routeRef(id: 'bogota:B74', shortName: 'B74'),
              headsign: null,
            ))));
    await tester.pump();
    expect(find.byKey(const ValueKey('boarding-destination')), findsOneWidget);
  });

  testWidgets('a stop without a code shows its name alone, not a dangling separator', (tester) async {
    final c = await _container();
    addTearDown(c.dispose);
    await tester.pumpWidget(_app(c, BoardingPass(cityId: 'bogota', leg: _trunkLeg(code: null))));
    await tester.pump();
    expect(find.text('San Victorino C - 4 ó 6'), findsOneWidget);
  });
}
