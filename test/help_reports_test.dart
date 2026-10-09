library;

/// Help and reports.
///
/// Asked for by TransMilenio against 1.16.0 (1.16): the app had links to the operator's channels
/// with nothing saying what each one answers, no emergency line, and no way to report that the app
/// itself is wrong.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/api/mock_api_client.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/providers.dart';
import 'package:opentransit_mobile/features/help/help_screen.dart';
import 'package:opentransit_mobile/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fixtures.dart';

final _mock = MockApiClient(bundle: DiskAssetBundle(), latency: Duration.zero);

/// The city the screen reads its channels from: three described pages and one emergency line, the
/// shape Bogotá's config has.
final _city = City.fromJson({
  'id': 'bogota',
  'name': 'Bogotá',
  'country': 'CO',
  'timezone': 'America/Bogota',
  'center': {'lat': 4.65, 'lon': -74.1},
  'bbox': [-74.3, 4.4, -73.9, 4.9],
  'links': {'pqrs': 'https://example.gov.co/pqrs'},
  'services': [
    {'id': 'pqrs', 'label': 'PQRS y reportes', 'icon': 'report', 'url': 'https://example.gov.co/pqrs',
     'kind': 'external', 'description': 'Respuesta formal con número de radicado.'},
    {'id': 'emergency', 'label': 'Emergencias 123', 'icon': 'emergency', 'phone': '123', 'kind': 'call',
     'emergency': true, 'description': 'Policía, ambulancia y bomberos.'},
  ],
});

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({'city': 'bogota'});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [
    sharedPrefsProvider.overrideWithValue(prefs),
    apiClientProvider.overrideWithValue(_mock),
    cityProvider('bogota').overrideWith((ref) async => _city),
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
        home: child,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => _mock.reports.clear());

  testWidgets('every channel says what it answers, and the emergency line dials', (tester) async {
    final c = await _container();
    addTearDown(c.dispose);
    await tester.pumpWidget(_app(c, const HelpScreen(cityId: 'bogota')));
    await tester.pump();
    await tester.pump();

    // The emergency line is its own block at the top, not one more row in a list of links.
    expect(find.byKey(const ValueKey('help-call-emergency')), findsOneWidget);
    expect(find.text('Policía, ambulancia y bomberos.'), findsOneWidget);

    // The operator's channels sit below the report form, so the list has to be scrolled to them.
    await tester.drag(find.byKey(const ValueKey('help-call-emergency')), const Offset(0, -500));
    await tester.pump();
    expect(find.text('Respuesta formal con número de radicado.'), findsOneWidget);
    expect(find.byKey(const ValueKey('help-channel-emergency')), findsNothing);
  });

  testWidgets('a report reaches the api with the kind the rider chose', (tester) async {
    final c = await _container();
    addTearDown(c.dispose);
    await tester.pumpWidget(_app(c, const HelpScreen(cityId: 'bogota')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('report-kind-barrier')));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('report-message')), 'La rampa está bloqueada');
    await tester.tap(find.byKey(const ValueKey('report-send')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(_mock.reports, hasLength(1));
    expect(_mock.reports.single['kind'], 'barrier');
    expect(_mock.reports.single['message'], 'La rampa está bloqueada');
    expect(find.byKey(const ValueKey('report-sent')), findsOneWidget);
  });

  testWidgets('the stop the rider came from travels with the report', (tester) async {
    final c = await _container();
    addTearDown(c.dispose);
    await tester.pumpWidget(_app(c, const HelpScreen(cityId: 'bogota', stopId: 'bogota:57866')));
    await tester.pump();

    expect(find.text('Adjunto: bogota:57866'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('report-message')), 'El paradero está al otro lado');
    await tester.tap(find.byKey(const ValueKey('report-send')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_mock.reports.single['stopId'], 'bogota:57866');
  });

  testWidgets('an empty report is not sent', (tester) async {
    final c = await _container();
    addTearDown(c.dispose);
    await tester.pumpWidget(_app(c, const HelpScreen(cityId: 'bogota')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('report-send')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_mock.reports, isEmpty);
    expect(find.byKey(const ValueKey('report-sent')), findsNothing);
  });

  test('a call channel is told apart from a page', () {
    final call = _city.services.firstWhere((s) => s.id == 'emergency');
    final page = _city.services.firstWhere((s) => s.id == 'pqrs');
    expect(call.isCall, isTrue);
    expect(call.emergency, isTrue);
    expect(page.isCall, isFalse);
    expect(page.emergency, isFalse);
  });
}
