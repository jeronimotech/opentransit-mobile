/// `PlanResponse.warnings` has been parsed since v1.4 and rendered nowhere, so a rider has never
/// been told why an option was dropped. The step-free warnings are what forced the issue: in seven
/// of our nine cities the accessibility toggle cannot filter anything, and the results come back
/// looking exactly like an unfiltered search.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/features/planner/widgets/plan_warnings.dart';
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

/// The shape the API actually sends: `CODE: sentence`.
const _unverified = 'ACCESSIBILITY_UNVERIFIED: this feed publishes the same wheelchair value for '
    'nearly every stop, or for too few of them; step-free results here are not a survey';
const _noData = 'ACCESSIBILITY_NO_DATA: this city publishes no stop or trip accessibility data, so '
    'the step-free option cannot filter anything';

void main() {
  group('which warnings are worth a line', () {
    late AppLocalizations l10n;

    setUp(() => l10n = lookupAppLocalizations(const Locale('es')));

    test('known codes are localised, not echoed in English', () {
      expect(PlanWarnings.line(l10n, _unverified), l10n.warnAccessibilityUnverified);
      expect(PlanWarnings.line(l10n, _noData), l10n.warnAccessibilityNoData);
      expect(PlanWarnings.line(l10n, 'MODE_NO_VEHICLES: BICYCLE_RENTAL'), l10n.warnNoSharedVehicles);
      expect(PlanWarnings.line(l10n, 'PARK_RIDE_NO_PARKING: none nearby'), l10n.warnNoParkRide);
    });

    test("OTP's own routing errors are localised, not forwarded in English", () {
      // `plan_from_otp` turns every routingError into `CODE: description`, so these arrived with
      // OTP's English text. They are also the warnings seen most, being the reason a search
      // returned nothing. Measured on production: a short Roma pair answers
      // WALKING_BETTER_THAN_TRANSIT.
      expect(PlanWarnings.line(l10n, 'WALKING_BETTER_THAN_TRANSIT: Walking is better than transit'),
          l10n.warnWalkingBetter);
      expect(PlanWarnings.line(l10n, 'NO_TRANSIT_CONNECTION: no connection'),
          l10n.warnNoTransitConnection);
      expect(PlanWarnings.line(l10n, 'NO_TRANSIT_CONNECTION_IN_SEARCH_WINDOW: none in window'),
          l10n.warnNoTransitInWindow);
      expect(PlanWarnings.line(l10n, 'OUTSIDE_SERVICE_PERIOD: too far ahead'),
          l10n.warnOutsideServicePeriod);
      expect(PlanWarnings.line(l10n, 'OUTSIDE_BOUNDS: off the graph'), l10n.warnOutsideBounds);
      expect(PlanWarnings.line(l10n, 'LOCATION_NOT_FOUND: no such place'),
          l10n.warnLocationNotFound);
      expect(PlanWarnings.line(l10n, 'NO_STOPS_IN_RANGE: nothing nearby'), l10n.warnNoStopsInRange);
      expect(PlanWarnings.line(l10n, 'SYSTEM_ERROR: boom'), l10n.warnRouterError);
    });

    test('nothing localised is left in English', () {
      // Every code the routers can emit, ours and OTP's. A new one still falls back to the
      // server's sentence, but none of these should reach that branch.
      const known = [
        'ACCESSIBILITY_UNVERIFIED', 'ACCESSIBILITY_NO_DATA', 'MODE_NO_VEHICLES',
        'PARK_RIDE_NO_PARKING', 'WALKING_BETTER_THAN_TRANSIT', 'NO_TRANSIT_CONNECTION',
        'NO_TRANSIT_CONNECTION_IN_SEARCH_WINDOW', 'OUTSIDE_SERVICE_PERIOD', 'OUTSIDE_BOUNDS',
        'LOCATION_NOT_FOUND', 'NO_STOPS_IN_RANGE', 'SYSTEM_ERROR',
      ];
      for (final code in known) {
        final line = PlanWarnings.line(l10n, '$code: some english sentence from the server');
        expect(line, isNotNull, reason: '$code produced no line');
        expect(line, isNot('some english sentence from the server'),
            reason: '$code fell through to the English fallback');
      }
    });

    test('NO_ITINERARIES is hidden, because the empty state already says it', () {
      expect(PlanWarnings.line(l10n, 'NO_ITINERARIES: no itineraries found'), isNull);
    });

    test('an unknown code falls back to the sentence the server sent', () {
      // English, but a rider reading "no legal curb space" learns more than from a blank screen,
      // and a new server warning must not be silently swallowed by an older app.
      expect(PlanWarnings.line(l10n, 'SOMETHING_NEW: the router ran out of patience'),
          'the router ran out of patience');
      expect(PlanWarnings.line(l10n, 'BARE_CODE_NO_TEXT'), 'BARE_CODE_NO_TEXT');
    });
  });

  group('the accessibility gap', () {
    test('is recognised from either step-free warning and nothing else', () {
      expect(PlanWarnings.hasAccessibilityGap([_unverified]), isTrue);
      expect(PlanWarnings.hasAccessibilityGap([_noData]), isTrue);
      expect(PlanWarnings.hasAccessibilityGap(['MODE_NO_VEHICLES: BICYCLE_RENTAL']), isFalse);
      expect(PlanWarnings.hasAccessibilityGap(const []), isFalse);
    });
  });

  testWidgets('nothing is drawn when the router had nothing to report', (tester) async {
    await tester.pumpWidget(_app(const PlanWarnings(warnings: [])));
    expect(find.byIcon(Icons.info_outline), findsNothing);
  });

  testWidgets('a step-free city with no data says so above the results', (tester) async {
    await tester.pumpWidget(_app(const PlanWarnings(warnings: [_noData])));
    final l10n = lookupAppLocalizations(const Locale('es'));
    expect(find.text(l10n.warnAccessibilityNoData), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
  });

  testWidgets('a hidden code does not leave an empty row behind', (tester) async {
    await tester.pumpWidget(_app(const PlanWarnings(warnings: ['NO_ITINERARIES: none found'])));
    expect(find.byIcon(Icons.info_outline), findsNothing);
  });

  testWidgets('several warnings each get their own line', (tester) async {
    await tester.pumpWidget(_app(
        const PlanWarnings(warnings: [_noData, 'MODE_NO_VEHICLES: BICYCLE_RENTAL'])));
    expect(find.byIcon(Icons.info_outline), findsNWidgets(2));
  });
}
