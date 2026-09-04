import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/providers.dart';
import 'package:opentransit_mobile/features/planner/widgets/itinerary_card.dart';
import 'package:opentransit_mobile/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fixtures.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('es')}) => ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(_prefs)],
      child: _App(locale: locale, child: child),
    );

late final SharedPreferences _prefs;

class _App extends StatelessWidget {
  const _App({required this.child, required this.locale});
  final Widget child;
  final Locale locale;
  @override
  Widget build(BuildContext context) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });
  final plan = PlanResponse.fromJson(loadFixture('plan'));

  testWidgets('shows route chips, duration, transfers and live badge (es)', (tester) async {
    final it = plan.itineraries[1]; // K43 + G12, 1 transfer, realtime on first leg
    var tapped = false;
    await tester.pumpWidget(_wrap(ItineraryCard(itinerary: it, onTap: () => tapped = true)));
    await tester.pump();

    expect(find.text('K43'), findsOneWidget);
    expect(find.text('G12'), findsOneWidget);
    expect(find.text('1 transbordo'), findsOneWidget);
    expect(find.textContaining('min'), findsWidgets);
    expect(find.text('En vivo'), findsOneWidget);
    expect(find.byIcon(Icons.directions_walk), findsWidgets);

    await tester.tap(find.byType(ItineraryCard));
    expect(tapped, isTrue);
  });

  testWidgets('localises to English', (tester) async {
    final it = plan.itineraries.first; // direct B10, 0 transfers
    await tester.pumpWidget(_wrap(ItineraryCard(itinerary: it), locale: const Locale('en')));
    await tester.pump();
    expect(find.text('No transfers'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('B10'), findsOneWidget);
  });

  testWidgets('shows the fare from the itinerary', (tester) async {
    final it = plan.itineraries.first; // fare 3200 COP estimated (fixture)
    await tester.pumpWidget(_wrap(ItineraryCard(itinerary: it)));
    await tester.pump();
    expect(find.textContaining('3.200'), findsOneWidget);
    expect(find.textContaining('≈'), findsOneWidget);
  });
}
