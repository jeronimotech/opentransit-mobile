import 'dart:convert';

import '../models/assistant.dart';
import 'sse.dart';

/// Turns one SSE frame into a typed [ChatEvent], or `null` when it carries
/// nothing this build understands.
///
/// The server names the frame in `event:` and puts the payload in `data:`.
/// A `type` inside the body wins when both are present, so a server that moves
/// the discriminator into the JSON keeps working. Unknown types are dropped
/// rather than guessed at: a newer server may stream frames this build cannot
/// draw, and the prose beside them still stands on its own.
ChatEvent? chatEventFrom(SseFrame frame) {
  final raw = frame.data.trim();
  if (raw.isEmpty || raw == '[DONE]') {
    return frame.event == 'done' ? const ChatDone() : null;
  }

  Map<String, dynamic> body;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      // A bare non-JSON `data:` under `event: token` is still a usable delta.
      return frame.event == 'token' ? ChatToken(frame.data) : null;
    }
    body = Map<String, dynamic>.from(decoded);
  } catch (_) {
    return frame.event == 'token' ? ChatToken(frame.data) : null;
  }

  final type = (body['type'] ?? frame.event ?? '').toString();
  switch (type) {
    case 'token':
      final text = body['text'] ?? body['delta'];
      return text is String && text.isNotEmpty ? ChatToken(text) : null;
    case 'tool':
      return ChatToolStarted(
        body['name']?.toString() ?? '',
        args: body['args'] is Map
            ? Map<String, dynamic>.from(body['args'] as Map)
            : null,
      );
    case 'card':
      return ChatCardEvent(body['kind']?.toString() ?? 'unknown', body['payload']);
    case 'done':
      final tools = body['toolsUsed'];
      return ChatDone(
        toolsUsed: tools is List ? tools.map((e) => e.toString()).toList() : const [],
        latencyMs: (body['latencyMs'] as num?)?.round(),
        costUsd: (body['costUsd'] as num?)?.toDouble(),
      );
    case 'error':
      return ChatError(
        body['code']?.toString() ?? 'ASSISTANT_UPSTREAM',
        body['message']?.toString() ?? '',
      );
    default:
      return null;
  }
}

/// Convenience for tests: a whole SSE body decoded into events.
List<ChatEvent> decodeChatStream(String text) {
  final out = <ChatEvent>[];
  final data = <String>[];
  String? event;

  void flush() {
    if (data.isEmpty && event == null) return;
    final frame = SseFrame(event, data.join('\n'));
    data.clear();
    event = null;
    final ev = chatEventFrom(frame);
    if (ev != null) out.add(ev);
  }

  for (final line in const LineSplitter().convert(text.replaceAll('\r\n', '\n'))) {
    if (line.isEmpty) {
      flush();
    } else if (line.startsWith(':')) {
      continue;
    } else if (line.startsWith('data:')) {
      data.add(line.substring(5).trimLeft());
    } else if (line.startsWith('event:')) {
      event = line.substring(6).trim();
    }
  }
  flush();
  return out;
}
