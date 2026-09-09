// Widget tests for the home action chips and the arrival board.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/api/mock_api_client.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/providers.dart';
import 'package:opentransit_mobile/features/home/widgets/action_chips.dart';
import 'package:opentransit_mobile/features/planner/follow_along_screen.dart';
import 'package:opentransit_mobile/features/stops/widgets/board_view.dart';
import 'package:opentransit_mobile/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fixtures.dart';

final _mock = MockApiClient(bundle: DiskAssetBundle(), now: DateTime.parse('2026-09-04T08:00:00-05:00'), latency: Duration.zero);

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({'city': 'bogota'});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [
    sharedPrefsProvider.overrideWithValue(prefs),
    apiClientProvider.overrideWithValue(_mock),
  ]);
  return c;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home action chips render the three actions, 44 pt tall, and report taps', (tester) async {
    final c = await _container();
    addTearDown(c.dispose);
    HomeAction? tapped;
    await tester.pumpWidget(_app(c, HomeActionChips(actions: HomeAction.values, onTap: (t) => tapped = t)));
    await tester.pump();
    expect(find.text('Planear viaje'), findsOneWidget);
    expect(find.text('Ubica tu bus'), findsOneWidget);
    expect(find.text('Buscar ruta'), findsOneWidget);
    // Nothing that duplicates the bottom nav.
    expect(find.text('Alertas'), findsNothing);
    expect(find.text('Favoritos'), findsNothing);
    expect(tester.getSize(find.byKey(const ValueKey('hub-locate'))).height, greaterThanOrEqualTo(44));
    await tester.tap(find.byKey(const ValueKey('hub-locate')));
    expect(tapped, HomeAction.locate);
  });

  testWidgets('board groups by route with next times and live badges', (tester) async {
    final c = await _container();
    // Fixture files are read with real IO, which FakeAsync never drains: warm
    // the mock's cache first so the providers resolve on plain pumps.
    await tester.runAsync(() async {
      await _mock.cities();
      await _mock.board('bogota', 'bogota:PN');
    });
    await tester.pumpWidget(_app(c, const SingleChildScrollView(child: BoardView(cityId: 'bogota', stopId: 'bogota:PN'))));
    // No pumpAndSettle: the live badge pulses forever.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Próximos buses'), findsOneWidget);
    expect(find.text('B10'), findsOneWidget);
    expect(find.text('K43'), findsOneWidget);
    expect(find.text('B74'), findsOneWidget);
    // Line 1: headsign + big first ETA on the right; line 2: "y en 13, 23 min".
    expect(find.text('Hacia Portal Sur'), findsOneWidget);
    expect(find.text('5 min'), findsOneWidget);
    expect(find.textContaining('Siguiente en'), findsNothing);
    expect(find.text('y en '), findsWidgets);
    expect(find.text(' min'), findsWidgets);
    expect(find.text(', '), findsWidgets);
    expect(find.byIcon(Icons.schedule), findsNothing);
    // Tear the tree down and dispose the container so the board's refresh
    // timer is cancelled before the framework checks for pending timers.
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  group('waiting for the bus, in GO', () {
    testWidgets('shows when this route reaches this stop, and keeps the exit in view', (tester) async {
      final c = await _container();
      final bus = PlanResponse.fromJson(loadFixture('plan')).itineraries.first.legs[1];
      // Warm the provider first: the mock reads fixtures off disk, which no amount of pumping
      // inside a widget test will complete on its own.
      final key = StopRouteKey('bogota', bus.from.stopId!, bus.route!.id);
      // runAsync, because the mock reads its fixtures off disk and real I/O does not advance
      // under the widget tester's fake clock — pumping alone waits forever.
      await tester.runAsync(() => c.read(nextBusesProvider(key).future));

      await tester.pumpWidget(_app(
        c,
        WaitingForBus(
          cityId: 'bogota',
          stopId: bus.from.stopId!,
          routeId: bus.route!.id,
          getOff: bus.to.name,
        ),
      ));
      await tester.pump();

      // the wait, not the distance to the stop where you get off
      expect(find.textContaining('min'), findsWidgets);
      expect(find.byKey(const ValueKey('go-eta-0')), findsOneWidget);
      // where this leg ends stays visible, one line, muted
      expect(find.textContaining(bus.to.name), findsOneWidget);

      // the arrivals refresh on a timer; unmount and dispose so it does not outlive the test
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  });
}
