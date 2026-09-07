// Widget tests for the assistant sheet (contract addendum v2.0, phase 1).
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/api/mock_api_client.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/providers.dart';
import 'package:opentransit_mobile/features/assistant/assistant_labels.dart';
import 'package:opentransit_mobile/features/assistant/chat_card_view.dart';
import 'package:opentransit_mobile/features/assistant/chat_controller.dart';
import 'package:opentransit_mobile/features/assistant/chat_sheet.dart';
import 'package:opentransit_mobile/l10n/generated/app_localizations.dart';
import 'package:opentransit_mobile/l10n/generated/app_localizations_es.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fixtures.dart';

final _mock = MockApiClient(
  bundle: DiskAssetBundle(),
  now: DateTime.parse('2026-09-04T08:00:00-05:00'),
  latency: Duration.zero,
);

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({'city': 'bogota'});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [
    sharedPrefsProvider.overrideWithValue(prefs),
    apiClientProvider.overrideWithValue(_mock),
    // No platform channel in a widget test, and the assistant must not wait
    // on one: it asks without a position when there is none.
    assistantPositionProvider.overrideWithValue(() async => null),
  ]);
}

/// Fixture files are read with real IO, which FakeAsync never drains: warm the
/// mock's cache first so the providers and the reply resolve on plain pumps.
Future<void> _warm(WidgetTester tester) => tester.runAsync(() async {
      await _mock.cities();
      await _mock.city('bogota');
      await _mock.board('bogota', 'bogota:PN');
      await _mock.alerts('bogota');
    });

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

/// The mock streams a word every 40 ms after a 220 ms beat per tool; a handful
/// of long pumps is enough to see a whole reply land.
Future<void> _settleStream(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// Tears the tree down and disposes the container inside the test body: the
/// analytics queue holds a periodic flush timer, and a card can carry a live
/// badge that pulses forever. Both outlive `addTearDown`, which runs after the
/// framework's pending-timer check.
Future<void> _close(WidgetTester tester, ProviderContainer c) async {
  await tester.pumpWidget(const SizedBox());
  c.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opens on the intro with three suggested prompts', (tester) async {
    final c = await _container();
    addTearDown(c.dispose);
    await _warm(tester);
    await tester.pumpWidget(_app(c, const AssistantSheet(cityId: 'bogota')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('¿Cómo llego al centro?'), findsOneWidget);
    expect(find.text('¿A qué hora pasa el próximo bus?'), findsOneWidget);
    expect(find.text('¿Hay desvíos hoy?'), findsOneWidget);
    // The suggestions are city-neutral: nothing here names one city's stops.
    expect(find.textContaining('Portal'), findsNothing);
  });

  testWidgets('names the provider once, then stops repeating itself', (tester) async {
    final c = await _container();
    await _warm(tester);
    await tester.pumpWidget(_app(c, const AssistantSheet(cityId: 'bogota')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final notice = find.byKey(const ValueKey('assistant-notice'));
    expect(notice, findsOneWidget);
    expect(tester.widget<Text>(notice).data, contains('DeepSeek'));

    await tester.tap(find.byKey(const ValueKey('assistant-suggestion-2')));
    await _settleStream(tester);
    expect(notice, findsNothing, reason: 'once per session, not once per question');
    await _close(tester, c);
  });

  testWidgets('a tool line, then its card, then the prose', (tester) async {
    final c = await _container();
    await _warm(tester);
    await tester.pumpWidget(_app(c, const AssistantSheet(cityId: 'bogota')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const ValueKey('assistant-suggestion-2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // The running tool is named in words, not as a function name.
    expect(find.text('Revisando desvíos…'), findsOneWidget);
    expect(find.text('service_alerts'), findsNothing);

    await _settleStream(tester);
    // The structured result is drawn with the app's own widgets, so the answer
    // is tappable instead of being a wall of prose.
    expect(find.byType(ChatCardView), findsWidgets);
    expect(find.textContaining('desvíos activos hoy'), findsOneWidget);
    expect(find.byKey(const ValueKey('assistant-thinking')), findsNothing);
    await _close(tester, c);
  });

  testWidgets('a refusal shows one plain sentence, not a code', (tester) async {
    final c = await _container();
    await _warm(tester);
    await tester.pumpWidget(_app(c, const AssistantSheet(cityId: 'bogota')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byKey(const ValueKey('assistant-input')), 'provoca un error');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('assistant-send')));
    await _settleStream(tester);

    expect(find.byKey(const ValueKey('assistant-error')), findsOneWidget);
    expect(find.text('No pude responder ahora mismo. Intenta de nuevo.'), findsOneWidget);
    expect(find.textContaining('ASSISTANT_'), findsNothing);
    await _close(tester, c);
  });

  testWidgets('the question is echoed and the field is cleared', (tester) async {
    final c = await _container();
    await _warm(tester);
    await tester.pumpWidget(_app(c, const AssistantSheet(cityId: 'bogota')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byKey(const ValueKey('assistant-input')), '¿Hay desvíos hoy?');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('assistant-send')));
    await tester.pump();
    expect(find.text('¿Hay desvíos hoy?'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const ValueKey('assistant-input'))).controller!.text,
      isEmpty,
    );
    await _settleStream(tester);
    await _close(tester, c);
  });

  group('entry point', () {
    final on = City.fromJson({
      'id': 'x',
      'name': 'X',
      'config': {'assistant': {'enabled': true, 'provider': 'openai'}},
    });
    final off = City.fromJson({'id': 'x', 'name': 'X', 'config': {}});

    test('needs the city to have it on and the API to be reachable', () {
      expect(assistantAvailable(on, online: true), isTrue);
      expect(assistantAvailable(on, online: false), isFalse);
      expect(assistantAvailable(off, online: true), isFalse);
      expect(assistantAvailable(null, online: true), isFalse);
    });
  });

  group('context sent with a question', () {
    test('coordinates are coarsened to ~110 m, as the notice promises', () {
      final ctx = chatContext(position: const LatLng(4.676543, -74.046789), locale: 'es');
      expect(ctx['lat'], 4.677);
      expect(ctx['lon'], -74.047);
      expect(ctx['locale'], 'es');
    });

    test('no position means no coordinates at all', () {
      expect(chatContext(locale: 'en').keys.toList(), ['locale']);
    });
  });

  group('a card leads into the app', () {
    test('the plan payload becomes a planner place', () {
      final plan = loadFixture('plan');
      final from = ChatCardView.placeFrom(plan['from']);
      final to = ChatCardView.placeFrom(plan['to']);
      expect(from!.position.lat, closeTo(4.756, 1e-6));
      expect(to!.position.lon, closeTo(-74.16, 1e-6));
      expect(from.name, isNotEmpty);
    });

    test('a payload without coordinates opens nothing rather than guessing', () {
      expect(ChatCardView.placeFrom({'name': 'Portal Norte'}), isNull);
      expect(ChatCardView.placeFrom(null), isNull);
      expect(ChatCardView.placeFrom('Portal Norte'), isNull);
    });
  });

  testWidgets('a new conversation clears the thread and mints a fresh session id', (tester) async {
    final c = await _container();
    await _warm(tester);
    await tester.pumpWidget(_app(c, const AssistantSheet(cityId: 'bogota')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final notifier = c.read(chatProvider.notifier);
    // Nothing to reset yet, so the action is inert rather than misleading.
    expect(tester.widget<IconButton>(find.byKey(const ValueKey('assistant-new'))).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('assistant-suggestion-2')));
    await _settleStream(tester);
    expect(c.read(chatProvider).turns, isNotEmpty);
    final before = notifier.sessionId;

    await tester.tap(find.byKey(const ValueKey('assistant-new')));
    await tester.pumpAndSettle();
    // Asks first: the thread lives only in memory, so clearing it is final.
    expect(find.byKey(const ValueKey('assistant-new-confirm')), findsOneWidget);
    await tester.tap(find.text('Empezar de nuevo'));
    await tester.pumpAndSettle();

    expect(c.read(chatProvider).turns, isEmpty);
    expect(find.text('¿Hay desvíos hoy?'), findsOneWidget, reason: 'the suggestions come back');
    expect(notifier.sessionId, isNot(before),
        reason: 'reusing the id would carry the old reply quota into the new conversation');
    await _close(tester, c);
  });

  testWidgets('cancelling the reset keeps the conversation', (tester) async {
    final c = await _container();
    await _warm(tester);
    await tester.pumpWidget(_app(c, const AssistantSheet(cityId: 'bogota')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const ValueKey('assistant-suggestion-2')));
    await _settleStream(tester);
    final turns = c.read(chatProvider).turns.length;
    final id = c.read(chatProvider.notifier).sessionId;

    await tester.tap(find.byKey(const ValueKey('assistant-new')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(c.read(chatProvider).turns.length, turns);
    expect(c.read(chatProvider.notifier).sessionId, id);
    await _close(tester, c);
  });

  group('tool labels', () {
    test('every tool the contract exposes has a sentence', () {
      final l10n = AppLocalizationsEs();
      for (final tool in assistantToolNames) {
        final label = assistantToolLabel(tool, l10n);
        expect(label, isNot(l10n.assistantThinking), reason: '$tool has no wording');
        expect(label.endsWith('…'), isTrue);
      }
    });

    test('a tool this build does not know falls back to "pensando…"', () {
      expect(assistantToolLabel('teleport', AppLocalizationsEs()), 'Pensando…');
    });

    test('each error code has its own sentence', () {
      final l10n = AppLocalizationsEs();
      final texts = {
        for (final code in ['ASSISTANT_BUDGET', 'ASSISTANT_DISABLED', 'ASSISTANT_RATE_LIMITED', 'ASSISTANT_UPSTREAM'])
          code: assistantErrorText(code, l10n),
      };
      expect(texts.values.toSet().length, 4);
      expect(assistantErrorText('WHO_KNOWS', l10n), texts['ASSISTANT_UPSTREAM']);
    });
  });
}
