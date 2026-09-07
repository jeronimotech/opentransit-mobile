import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/api/chat_events.dart';
import 'package:opentransit_mobile/core/api/sse.dart';
import 'package:opentransit_mobile/core/models/assistant.dart';

/// The exact framing the live API emits (captured from
/// `POST /v1/cities/bogota/chat` on 2026-09-07): the type is in `event:`, the
/// payload is a single-line JSON `data:`, and frames end on a blank line.
const _liveStream = '''
event: tool
data: {"name": "find_place", "args": {"query": "Parque de la 93", "near": null}}

event: card
data: {"kind": "place", "payload": {"name": "Parque de la 93", "lat": 4.676, "lon": -74.046}}

event: tool
data: {"name": "plan_trip", "args": {"fromLat": 4.676, "fromLon": -74.046}}

event: card
data: {"kind": "itineraries", "payload": {"itineraries": [{"id": "it-0"}]}}

event: token
data: {"text": "La"}

event: token
data: {"text": " opción"}

event: done
data: {"usage": {"inputTokens": 6963, "outputTokens": 545}, "toolsUsed": ["find_place", "plan_trip"], "latencyMs": 12885, "costUsd": 0.011349}

''';

void main() {
  group('SSE decoding', () {
    test('decodes the live framing into typed events, in order', () {
      final events = decodeChatStream(_liveStream);
      expect(events.map((e) => e.runtimeType).toList(), [
        ChatToolStarted,
        ChatCardEvent,
        ChatToolStarted,
        ChatCardEvent,
        ChatToken,
        ChatToken,
        ChatDone,
      ]);
      expect((events[0] as ChatToolStarted).name, 'find_place');
      expect((events[1] as ChatCardEvent).kind, 'place');
      final done = events.last as ChatDone;
      expect(done.toolsUsed, ['find_place', 'plan_trip']);
      expect(done.costUsd, closeTo(0.011349, 1e-9));
    });

    test('a card arrives before any prose', () {
      final events = decodeChatStream(_liveStream);
      final firstCard = events.indexWhere((e) => e is ChatCardEvent);
      final firstToken = events.indexWhere((e) => e is ChatToken);
      expect(firstCard, lessThan(firstToken),
          reason: 'the contract shows the structured result as soon as the tool returns');
    });

    test('an event split across chunk boundaries is still decoded', () async {
      // Chop the stream at awkward places: mid-field, mid-JSON and mid-newline.
      final chunks = <String>[];
      const size = 17;
      for (var i = 0; i < _liveStream.length; i += size) {
        chunks.add(_liveStream.substring(
            i, i + size > _liveStream.length ? _liveStream.length : i + size));
      }
      final bytes = Stream<List<int>>.fromIterable(
          chunks.map((c) => utf8.encode(c)).toList());

      final out = <ChatEvent>[];
      await for (final f in parseSseFrames(bytes)) {
        final ev = chatEventFrom(f);
        if (ev != null) out.add(ev);
      }
      expect(out.length, 7);
      expect(out.whereType<ChatToken>().map((t) => t.text).join(), 'La opción');
    });

    test('keep-alive comments and unknown frames are skipped, not fatal', () {
      final events = decodeChatStream(
        ': keep-alive\n\nevent: token\ndata: {"text":"hola"}\n\n'
        'event: futureThing\ndata: {"x":1}\n\nevent: done\ndata: {}\n\n',
      );
      expect(events.length, 2);
      expect((events.first as ChatToken).text, 'hola');
      expect(events.last, isA<ChatDone>());
    });

    test('a type inside the body wins over the event name', () {
      final events = decodeChatStream('event: token\ndata: {"type":"error","code":"ASSISTANT_BUDGET","message":"x"}\n\n');
      expect((events.single as ChatError).code, 'ASSISTANT_BUDGET');
    });
  });

  group('error codes', () {
    test('each documented code maps to its own sentence', () {
      expect(assistantErrorKind('ASSISTANT_BUDGET'), AssistantErrorKind.budget);
      expect(assistantErrorKind('ASSISTANT_DISABLED'), AssistantErrorKind.disabled);
      expect(assistantErrorKind('ASSISTANT_RATE_LIMITED'), AssistantErrorKind.rateLimited);
      expect(assistantErrorKind('ASSISTANT_UPSTREAM'), AssistantErrorKind.upstream);
    });

    test('an unknown code reads as the provider being down', () {
      expect(assistantErrorKind('SOMETHING_NEW'), AssistantErrorKind.upstream);
    });
  });

  group('turn folding', () {
    test('tokens accumulate and clear the running tool', () {
      final t = ChatTurn(id: 'a', role: 'assistant');
      t.apply(const ChatToolStarted('plan_trip'));
      expect(t.tool, 'plan_trip');
      t.apply(const ChatToken('Hola'));
      t.apply(const ChatToken(' mundo'));
      expect(t.text, 'Hola mundo');
      expect(t.tool, isNull, reason: 'prose means the tool finished');
    });

    test('an error ends the turn', () {
      final t = ChatTurn(id: 'a', role: 'assistant');
      t.apply(const ChatError('ASSISTANT_BUDGET', 'sin presupuesto'));
      expect(t.done, isTrue);
      expect(t.error!.code, 'ASSISTANT_BUDGET');
    });
  });

  group('card kinds', () {
    test('the server\'s plural kinds pass through unchanged', () {
      for (final k in ['itineraries', 'fares', 'board', 'next', 'alerts', 'place', 'vehicles', 'stops', 'routes', 'bikeStations']) {
        expect(const ChatCard('x', null).kind, isNotNull);
        expect(ChatCard(k, null).normalized, k);
      }
    });

    test('singular spellings are accepted so a card is never silently dropped', () {
      expect(ChatCard('itinerary', null).normalized, 'itineraries');
      expect(ChatCard('fare', null).normalized, 'fares');
      expect(ChatCard('stop', null).normalized, 'stops');
      expect(ChatCard('route', null).normalized, 'routes');
    });
  });

  group('what leaves the device', () {
    test('the wire carries role and text only', () {
      final turns = [
        ChatTurn(id: '1', role: 'user', text: '¿Cómo llego?'),
        ChatTurn(id: '2', role: 'assistant', text: 'Así', cards: [const ChatCard('place', {'lat': 4.6})]),
        ChatTurn(id: '3', role: 'assistant', text: '', error: const ChatError('X', 'y')),
      ];
      final wire = wireMessages(turns);
      expect(wire, [
        {'role': 'user', 'content': '¿Cómo llego?'},
        {'role': 'assistant', 'content': 'Así'},
      ]);
      expect(jsonEncode(wire).contains('lat'), isFalse,
          reason: 'cards and coordinates never go back up');
    });

    test('the analytics event carries no text and no coordinates', () {
      final props = assistantQueryProps(
        toolsUsed: ['plan_trip', 'plan_trip', 'find_place'],
        latencyMs: 1234,
        ok: true,
      );
      expect(props.keys.toSet(), {'toolsUsed', 'latencyMs', 'ok'});
      expect(props['toolsUsed'], ['plan_trip', 'find_place']);
      // Match JSON *keys*, not substrings: "latencyMs" legitimately contains "lat".
      final encoded = jsonEncode(props);
      for (final forbidden in ['lat', 'lon', 'content', 'text', 'query', 'sessionId']) {
        expect(encoded.contains('"$forbidden"'), isFalse,
            reason: '$forbidden must never be logged');
      }
    });

    test('a negative latency is clamped rather than stored', () {
      expect(assistantQueryProps(toolsUsed: const [], latencyMs: -5, ok: false)['latencyMs'], 0);
    });
  });

  group('provider label', () {
    test('falls back to a readable name when the API does not send one', () {
      expect(const AssistantPublic(provider: 'deepseek').label, 'DeepSeek');
      expect(const AssistantPublic(provider: 'anthropic').label, 'Anthropic');
    });

    test('the API\'s own name wins', () {
      expect(
        const AssistantPublic(provider: 'deepseek', providerName: 'DeepSeek v4').label,
        'DeepSeek v4',
      );
    });

    test('an unknown provider still shows something', () {
      expect(const AssistantPublic(provider: 'mistral').label, 'mistral');
    });
  });
}
