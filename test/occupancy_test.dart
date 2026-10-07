library;

/// Occupancy arrives as GTFS-RT's protobuf enum name and used to be formatted by a `switch` living
/// on the vehicle detail screen whose default branch printed the raw name. Measured against
/// production on 2026-10-07, Lisboa publishes `NO_DATA_AVAILABLE` for all thirteen of its vehicles,
/// so that default branch was one screen away from showing a rider the string `NO_DATA_AVAILABLE`.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/widgets/common.dart';
import 'package:opentransit_mobile/l10n/generated/app_localizations.dart';

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

Vehicle _vehicle({String? occupancy}) => Vehicle.fromJson({
      'id': 'V1',
      'lat': 4.63,
      'lon': -74.08,
      'occupancy': ?occupancy,
    });

void main() {
  group('parsing the feed value', () {
    test('every level the spec defines is recognised', () {
      expect(Occupancy.parse('EMPTY'), Occupancy.empty);
      expect(Occupancy.parse('MANY_SEATS_AVAILABLE'), Occupancy.manySeats);
      expect(Occupancy.parse('FEW_SEATS_AVAILABLE'), Occupancy.fewSeats);
      expect(Occupancy.parse('STANDING_ROOM_ONLY'), Occupancy.standing);
      expect(Occupancy.parse('CRUSHED_STANDING_ROOM_ONLY'), Occupancy.crushed);
      expect(Occupancy.parse('FULL'), Occupancy.full);
      expect(Occupancy.parse('NOT_ACCEPTING_PASSENGERS'), Occupancy.notAccepting);
    });

    test('a feed saying it does not know is not a crowding level', () {
      // Lisboa sends this for every vehicle. Drawing it as "empty" would invent a measurement.
      expect(Occupancy.parse('NO_DATA_AVAILABLE'), Occupancy.unknown);
      expect(Occupancy.parse('NOT_BOARDABLE'), Occupancy.unknown);
      expect(Occupancy.parse(null), Occupancy.unknown);
      expect(Occupancy.parse(''), Occupancy.unknown);
      // and a value the spec gains after this app ships
      expect(Occupancy.parse('SOMETHING_NEW'), Occupancy.unknown);
    });

    test('a vehicle reads its own level, and Bogota has none to read', () {
      expect(_vehicle(occupancy: 'FEW_SEATS_AVAILABLE').crowding, Occupancy.fewSeats);
      expect(_vehicle().crowding, Occupancy.unknown);
      expect(_vehicle().crowding.isKnown, isFalse);
    });
  });

  group('how full is full', () {
    test('dots climb with crowding and stop at three', () {
      expect(Occupancy.empty.dots, 1);
      expect(Occupancy.manySeats.dots, 1);
      expect(Occupancy.fewSeats.dots, 2);
      expect(Occupancy.standing.dots, 3);
      expect(Occupancy.crushed.dots, 3);
      expect(Occupancy.full.dots, 3);
      expect(Occupancy.unknown.dots, 0);
    });

    test('severe is about boarding, not about comfort', () {
      // Standing is unpleasant; full and not-accepting mean you may not get on at all, which is
      // the only distinction worth a different colour.
      expect(Occupancy.standing.isSevere, isFalse);
      expect(Occupancy.crushed.isSevere, isFalse);
      expect(Occupancy.full.isSevere, isTrue);
      expect(Occupancy.notAccepting.isSevere, isTrue);
    });
  });

  testWidgets('an unknown level draws nothing at all', (tester) async {
    await tester.pumpWidget(_app(const OccupancyBadge(occupancy: Occupancy.unknown)));
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('a known level shows its word, never the enum name', (tester) async {
    await tester.pumpWidget(_app(const OccupancyBadge(occupancy: Occupancy.fewSeats)));
    final l10n = lookupAppLocalizations(const Locale('es'));
    expect(find.text(l10n.occupancyFewSeats), findsOneWidget);
    expect(find.textContaining('FEW_SEATS'), findsNothing);
  });

  testWidgets('dots alone fit a row with no width to spare', (tester) async {
    await tester.pumpWidget(
        _app(const OccupancyBadge(occupancy: Occupancy.full, showLabel: false)));
    expect(find.byType(Text), findsNothing);
    expect(tester.widgetList<Container>(find.byType(Container)).length, 3);
  });
}
