// The "Programar viaje" sheet: weekday chips, one-off date, arrive-by/leave-at, and saving stores a
// trip the trips screen then lists with its schedule label.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/api/mock_api_client.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/providers.dart';
import 'package:opentransit_mobile/features/trips/schedule_trip_sheet.dart';
import 'package:opentransit_mobile/features/trips/trips_screen.dart';
import 'package:opentransit_mobile/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fixtures.dart';

const home = Place(name: 'Casa', position: LatLng(4.7420, -74.0930));
const work = Place(name: 'Trabajo', position: LatLng(4.6010, -74.0720));

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      apiClientProvider.overrideWithValue(MockApiClient(bundle: DiskAssetBundle(), now: DateTime(2026, 9, 14, 10), latency: Duration.zero)),
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

  testWidgets('saving from the sheet stores a weekday trip and the list shows it', (tester) async {
    await tester.pumpWidget(host(Consumer(builder: (context, ref, _) => TextButton(
          key: const ValueKey('open'),
          onPressed: () => showScheduleTripSheet(context, ref, cityId: 'bogota', from: home, to: work, hour: 8),
          child: const Text('open'),
        ))));
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
    expect(find.text('Programar viaje'), findsOneWidget);
    expect(find.text('Casa → Trabajo'), findsOneWidget);
    // weekdays are pre-selected; drop Friday
    await tester.tap(find.byKey(const ValueKey('schedule-day-5')));
    await tester.pumpAndSettle();
    // saving plans the trip through the (file-backed) mock client: real IO, so let it run
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('schedule-save')));
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();

    final trips = container.read(scheduledTripsProvider);
    expect(trips, hasLength(1));
    final t = trips.single;
    expect(t.days, {DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday});
    expect(t.arriveBy, isTrue);
    expect(t.hour, 8);
    expect(t.from.name, 'Casa');
    // the sheet closed and said what will happen
    expect(find.text('Programar viaje'), findsNothing);

    await tester.pumpWidget(host(const TripsScreen(cityId: 'bogota')));
    await tester.pumpAndSettle();
    expect(find.text('Casa → Trabajo'), findsOneWidget);
    expect(find.textContaining('llegar'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('a one-off date replaces the weekdays and can be switched to leave-at', (tester) async {
    await tester.pumpWidget(host(Consumer(builder: (context, ref, _) => TextButton(
          key: const ValueKey('open'),
          onPressed: () => showScheduleTripSheet(context, ref, cityId: 'bogota', from: home, to: work, hour: 10, minute: 30),
          child: const Text('open'),
        ))));
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salir a las'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('schedule-once')));
    await tester.pumpAndSettle();
    final ok = MaterialLocalizations.of(tester.element(find.byKey(const ValueKey('schedule-once')))).okButtonLabel;
    await tester.tap(find.text(ok));            // the date picker's default (tomorrow)
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('schedule-save')));
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();
    final t = container.read(scheduledTripsProvider).single;
    expect(t.date, isNotNull);
    expect(t.days, isEmpty);
    expect(t.arriveBy, isFalse);
    expect(t.minute, 30);
  });

  test('schedule labels', () {
    final l10n = lookupAppLocalizations(const Locale('es'));
    ScheduledTrip trip(Set<int> days, {DateTime? date}) => ScheduledTrip(
        id: 'x', cityId: 'bogota', from: home, to: work, hour: 8, minute: 0, days: days, date: date);
    expect(scheduleLabel(trip({1, 2, 3, 4, 5}), l10n, 'es'), 'Lun–Vie');
    expect(scheduleLabel(trip({1, 2, 3, 4, 5, 6, 7}), l10n, 'es'), 'Todos los días');
    expect(scheduleLabel(trip({6, 7}), l10n, 'es'), 'Fin de semana');
    expect(scheduleLabel(trip({1, 3}), l10n, 'es'), 'lun mié');
    expect(scheduleLabel(trip(const {}, date: DateTime(2026, 9, 20)), l10n, 'es'), contains('20'));
  });
}
