import 'common.dart';

/// The public slice of a city's assistant settings. The key never leaves the
/// server, so this is everything the app is allowed to know.
class AssistantPublic {
  const AssistantPublic({
    this.enabled = false,
    this.provider = 'anthropic',
    this.model,
    this.providerName,
  });

  final bool enabled;
  final String provider;
  final String? model;

  /// Set when the API names the provider itself; otherwise we label it locally.
  final String? providerName;

  static const _labels = <String, String>{
    'anthropic': 'Anthropic',
    'openai': 'OpenAI',
    'deepseek': 'DeepSeek',
    'gemini': 'Google Gemini',
  };

  /// What to show the user in the one-time notice.
  String get label => providerName ?? _labels[provider] ?? provider;

  factory AssistantPublic.fromJson(Map<String, dynamic>? j) => j == null
      ? const AssistantPublic()
      : AssistantPublic(
          enabled: asBool(j['enabled'], fallback: false),
          provider: j['provider']?.toString() ?? 'anthropic',
          model: j['model']?.toString(),
          providerName: j['providerName']?.toString(),
        );
}

/// One streamed frame of a reply, already typed.
sealed class ChatEvent {
  const ChatEvent();
}

class ChatToken extends ChatEvent {
  const ChatToken(this.text);
  final String text;
}

class ChatToolStarted extends ChatEvent {
  const ChatToolStarted(this.name, {this.args});
  final String name;
  final Map<String, dynamic>? args;
}

class ChatCardEvent extends ChatEvent {
  const ChatCardEvent(this.kind, this.payload);
  final String kind;
  final Object? payload;
}

class ChatDone extends ChatEvent {
  const ChatDone({this.toolsUsed = const [], this.latencyMs, this.costUsd});
  final List<String> toolsUsed;
  final int? latencyMs;
  final double? costUsd;
}

class ChatError extends ChatEvent {
  const ChatError(this.code, this.message);
  final String code;
  final String message;
}

/// Which plain sentence to show. Anything we cannot name reads as "the provider
/// is down", which is the honest description of an unknown failure.
enum AssistantErrorKind { budget, disabled, rateLimited, upstream }

AssistantErrorKind assistantErrorKind(String code) => switch (code) {
      'ASSISTANT_BUDGET' => AssistantErrorKind.budget,
      'ASSISTANT_DISABLED' => AssistantErrorKind.disabled,
      'ASSISTANT_RATE_LIMITED' => AssistantErrorKind.rateLimited,
      _ => AssistantErrorKind.upstream,
    };

/// A structured tool result, kept raw so the card widgets can decode the parts
/// they need without this layer knowing every payload shape.
class ChatCard {
  const ChatCard(this.kind, this.payload);
  final String kind;
  final Object? payload;

  Map<String, dynamic>? get map =>
      payload is Map ? Map<String, dynamic>.from(payload as Map) : null;

  /// The server's kinds are plural (`itineraries`, `fares`, `stops`, `routes`);
  /// singular spellings are accepted too so a differently-worded server still
  /// renders instead of silently dropping the card.
  String get normalized => switch (kind) {
        'itinerary' => 'itineraries',
        'fare' => 'fares',
        'stop' => 'stops',
        'route' => 'routes',
        'alert' => 'alerts',
        'vehicle' => 'vehicles',
        'bikeStation' || 'bike_stations' => 'bikeStations',
        _ => kind,
      };
}

/// One turn of the conversation as the UI holds it.
class ChatTurn {
  ChatTurn({
    required this.id,
    required this.role,
    this.text = '',
    List<ChatCard>? cards,
    this.tool,
    this.done = false,
    this.error,
  }) : cards = cards ?? <ChatCard>[];

  final String id;
  final String role; // 'user' | 'assistant'
  String text;
  final List<ChatCard> cards;

  /// The tool running right now, for the "pensando…" line.
  String? tool;
  bool done;
  ChatError? error;

  bool get isUser => role == 'user';

  /// Folds one event into this turn. Kept here (and pure enough to test) so the
  /// ordering the contract cares about — a card lands as soon as its tool
  /// returns, before any prose — is verifiable without building a widget.
  void apply(ChatEvent ev) {
    switch (ev) {
      case ChatToken(:final text):
        this.text += text;
        tool = null;
      case ChatToolStarted(:final name):
        tool = name;
      case ChatCardEvent(:final kind, :final payload):
        cards.add(ChatCard(kind, payload));
        tool = null;
      case ChatDone():
        done = true;
        tool = null;
      case ChatError():
        error = ev;
        done = true;
        tool = null;
    }
  }
}

/// Only what the API needs: role and text. Cards, ids and errors stay local.
List<Map<String, String>> wireMessages(List<ChatTurn> turns) => [
      for (final t in turns)
        if (t.text.trim().isNotEmpty && t.error == null)
          {'role': t.role, 'content': t.text},
    ];

/// The only analytics the assistant emits. `CONTRACT-analytics.md` forbids free
/// text, so this is built from three values and nothing else: neither the
/// question nor where it was asked can be reconstructed from it.
Map<String, dynamic> assistantQueryProps({
  required List<String> toolsUsed,
  required int latencyMs,
  required bool ok,
}) =>
    {
      'toolsUsed': {...toolsUsed}.toList(),
      'latencyMs': latencyMs < 0 ? 0 : latencyMs,
      'ok': ok,
    };

/// The `context` the client sends with a question.
///
/// The one-time notice tells the user we do not send their exact location, so
/// the coordinates are rounded to three decimals (~110 m) before they leave —
/// close enough to plan the first walking leg from, too coarse to be a
/// position fix. `CONTRACT-analytics.md` coarsens the same way. A null
/// position simply omits the keys: the model then works from a named place.
Map<String, dynamic> chatContext({LatLng? position, required String locale}) {
  double round3(double v) => (v * 1000).round() / 1000;
  return {
    'locale': locale,
    if (position != null) 'lat': round3(position.lat),
    if (position != null) 'lon': round3(position.lon),
  };
}

/// The ten tools the contract exposes, mapped to the sentence shown while one
/// is running. An unnamed or newer tool falls back to a plain "pensando…" at
/// the call site rather than showing a raw function name.
const assistantToolNames = <String>{
  'plan_trip',
  'find_place',
  'next_departures',
  'locate_bus',
  'service_alerts',
  'fare_estimate',
  'nearby_stops',
  'bike_stations',
  'vehicles_near',
  'route_info',
};
