library;

/// The published schedule of a route, and the connections along it.
///
/// Asked for by TransMilenio against 1.16.0 (1.12): the route page could say whether a route runs
/// now and not how long a rider would wait, and nothing about what they could change to.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/api/mock_api_client.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/features/routes/widgets/schedule_sheet.dart';
import 'package:opentransit_mobile/l10n/generated/app_localizations.dart';

import 'helpers/fixtures.dart';

final _json = {
  'routeId': 'bogota:B74',
  'patternId': 'p-1',
  'headsign': 'Museo Nacional',
  'date': '2026-10-09',
  'source': 'schedule',
  'trips': 3,
  'first': '05:10',
  'last': '22:40',
  'typicalHeadwayMinutes': 6,
  'frequent': true,
  'bands': [
    {'hour': 5, 'from': '05:00', 'to': '06:00', 'trips': 2, 'headwayMinutes': {'min': 5, 'typical': 6, 'max': 8}},
    {'hour': 22, 'from': '22:00', 'to': '23:00', 'trips': 1, 'headwayMinutes': null},
  ],
  'departures': ['05:10', '05:16', '22:40'],
  'connections': [
    {'stopId': 'bogota:PN', 'name': 'Portal Norte', 'routes': [
      {'id': 'bogota:K43', 'shortName': 'K43', 'longName': 'Portal Norte - Ricaurte', 'mode': 'BUS'},
    ]},
    {'stopId': 'bogota:C45', 'name': 'Calle 45', 'routes': []},
  ],
};

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parsing', () {
    final s = PatternSchedule.fromJson(_json);

    test('the summary comes through', () {
      expect(s.trips, 3);
      expect(s.first, '05:10');
      expect(s.last, '22:40');
      expect(s.typicalHeadwayMinutes, 6);
      expect(s.frequent, isTrue);
    });

    test('an hour holding the last departure has a count and no interval', () {
      expect(s.bands.last.trips, 1);
      expect(s.bands.last.headway, isNull);
      expect(s.bands.first.headway!.typical, 6);
    });

    test('connections are keyed by stop, including the stops with none', () {
      expect(s.routesByStop['bogota:PN']!.map((r) => r.shortName), ['K43']);
      expect(s.routesByStop['bogota:C45'], isEmpty);
    });
  });

  testWidgets('the sheet leads with the interval and lists every departure', (tester) async {
    await tester.pumpWidget(_app(ScheduleSheet(
      schedule: PatternSchedule.fromJson(_json),
      routeName: 'B74',
    )));
    await tester.pump();
    expect(find.textContaining('Cada 6 min'), findsWidgets);
    // The intervals are ours, and the sheet says so rather than implying the feed published them.
    expect(find.text('Intervalos calculados del horario publicado'), findsOneWidget);
    expect(find.text('05:16'), findsOneWidget);
    expect(find.text('22:40'), findsWidgets);
  });

  // "1 salidas" was what this used to read: the string is a plural message, not a count plus a
  // fixed word.
  testWidgets('an hour with a single departure shows the count, not a zero wait', (tester) async {
    await tester.pumpWidget(_app(ScheduleSheet(
      schedule: PatternSchedule.fromJson(_json),
      routeName: 'B74',
    )));
    await tester.pump();
    expect(find.text('1 salida'), findsWidgets);
  });

  test('the mock answers the same shape, so the demo shows the real screen', () async {
    final api = MockApiClient(bundle: DiskAssetBundle(), latency: Duration.zero);
    final s = await api.routeSchedule('bogota', 'bogota:B74');
    expect(s.trips, greaterThan(0));
    expect(s.departures.first.length, 5);
    expect(s.frequent, isTrue);
    // B74 and K43 share Portal Norte in the fixture network.
    expect(s.routesByStop['bogota:PN']!.map((r) => r.shortName), contains('K43'));
    expect(s.routesByStop['bogota:PN']!.map((r) => r.shortName), isNot(contains('B74')));
  });
}
