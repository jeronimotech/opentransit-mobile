library;

/// The "also serve this segment" block, end to end over the fixture network.
///
/// PN -> C45 is run by B10, K43 and B74; B10 also runs it southbound, which must not count twice.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/api/mock_api_client.dart';
import 'package:opentransit_mobile/core/providers.dart';
import 'package:opentransit_mobile/features/planner/widgets/equivalent_services.dart';
import 'package:opentransit_mobile/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fixtures.dart';

final _mock = MockApiClient(bundle: DiskAssetBundle(), latency: Duration.zero);

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({'city': 'bogota'});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [
    sharedPrefsProvider.overrideWithValue(prefs),
    apiClientProvider.overrideWithValue(_mock),
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

/// The mock reads its fixtures off disk, and a widget test's fake-async zone never completes real
/// file I/O: the warm-up has to run outside it, after which the widget's own call resolves from the
/// cache on a microtask. Bounded pumps for the same reason — nothing here settles on its own.
Future<void> _warm(WidgetTester tester) =>
    tester.runAsync(() => _mock.segmentServices('bogota', 'bogota:PN', 'bogota:C45'));

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('an eager block lists the other services running the segment', (tester) async {
    await _warm(tester);
    final c = await _container();
    addTearDown(c.dispose);
    await tester.pumpWidget(_app(
        c,
        const EquivalentServices(
          cityId: 'bogota',
          fromStopId: 'bogota:PN',
          toStopId: 'bogota:C45',
          routeId: 'bogota:B10',
          boardingStopName: 'Portal Norte',
          eager: true,
        )));
    await _settle(tester);
    expect(find.text('También sirven este tramo'), findsOneWidget);
    expect(find.text('K43'), findsOneWidget);
    expect(find.text('B74'), findsOneWidget);
    // The leg's own route is already on the card above.
    expect(find.text('B10'), findsNothing);
  });

  testWidgets('a later leg asks first, and answers after the tap', (tester) async {
    await _warm(tester);
    final c = await _container();
    addTearDown(c.dispose);
    await tester.pumpWidget(_app(
        c,
        const EquivalentServices(
          cityId: 'bogota',
          fromStopId: 'bogota:PN',
          toStopId: 'bogota:C45',
          routeId: 'bogota:B10',
        )));
    await _settle(tester);
    expect(find.byKey(const ValueKey('equivalents')), findsNothing);
    expect(find.text('Otros servicios en este tramo'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('equivalents-ask')));
    await _settle(tester);
    expect(find.text('K43'), findsOneWidget);
  });

  testWidgets('a segment nothing else serves shows nothing at all', (tester) async {
    await _warm(tester);
    final c = await _container();
    addTearDown(c.dispose);
    await tester.pumpWidget(_app(
        c,
        const EquivalentServices(
          cityId: 'bogota',
          fromStopId: 'bogota:TUN',
          toStopId: 'bogota:MIR',
          routeId: 'bogota:L10',
          eager: true,
        )));
    await _settle(tester);
    expect(find.byKey(const ValueKey('equivalents')), findsNothing);
    expect(find.text('También sirven este tramo'), findsNothing);
  });
}
