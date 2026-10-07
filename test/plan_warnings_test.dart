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
