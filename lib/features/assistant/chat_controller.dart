import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics/analytics_event.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/utils/location.dart';

/// The conversation as the sheet sees it.
///
/// Held above the sheet on purpose: closing the sheet to look at an itinerary
/// and coming back should not wipe the thread. It lives only in memory, so the
/// conversation is gone when the app is, which is what the notice promises.
class ChatState {
  const ChatState({
    this.cityId,
    this.turns = const [],
    this.busy = false,
    this.noticePending = true,
  });

  final String? cityId;
  final List<ChatTurn> turns;
  final bool busy;

  /// True until the provider notice has been shown once this session.
  final bool noticePending;

  bool get isEmpty => turns.isEmpty;

  ChatState copyWith({
    String? cityId,
    List<ChatTurn>? turns,
    bool? busy,
    bool? noticePending,
  }) =>
      ChatState(
        cityId: cityId ?? this.cityId,
        turns: turns ?? this.turns,
        busy: busy ?? this.busy,
        noticePending: noticePending ?? this.noticePending,
      );
}

/// How the assistant obtains a position. A seam, not a preference: tests and
/// the screenshot walkthrough override it so a question never blocks on a
/// platform channel, and the app itself never prompts (see [grantedPosition]).
final assistantPositionProvider =
    Provider<Future<LatLng?> Function()>((_) => grantedPosition);

class ChatNotifier extends Notifier<ChatState> {
  StreamSubscription<ChatEvent>? _sub;
  String? _sessionId;
  var _seq = 0;

  @override
  ChatState build() {
    ref.onDispose(_stop);
    return const ChatState();
  }

  /// A random id per app run. It groups the turns of one conversation for the
  /// server's rate limit and nothing else: it is not stored and not tied to
  /// the device, the installation or any analytics id.
  String get sessionId =>
      _sessionId ??= 's-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
          '${Random().nextInt(1 << 32).toRadixString(36)}';

  /// Called when the sheet opens. Changing city starts a new conversation:
  /// the answers are about a network the user has left.
  void open(String cityId) {
    if (state.cityId == cityId) return;
    _stop();
    _sessionId = null;
    state = ChatState(cityId: cityId);
  }

  void dismissNotice() {
    if (state.noticePending) state = state.copyWith(noticePending: false);
  }

  /// Stops a reply in flight, keeping whatever prose already arrived.
  void cancel() {
    if (!state.busy) return;
    _stop();
    final turns = state.turns;
    if (turns.isNotEmpty) turns.last.done = true;
    state = state.copyWith(turns: List.of(turns), busy: false);
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
  }

  /// Sends one question and folds the reply in as it streams.
  Future<void> ask(String cityId, String question, {String locale = 'es'}) async {
    final q = question.trim();
    if (q.isEmpty || state.busy) return;
    _stop();
    dismissNotice();

    final answer = ChatTurn(id: 'a${_seq++}', role: 'assistant');
    final turns = [
      ...state.turns,
      ChatTurn(id: 'u${_seq++}', role: 'user', text: q, done: true),
      answer,
    ];
    state = ChatState(cityId: cityId, turns: turns, busy: true, noticePending: false);

    // Only ever the position the user already granted, and only coarsened.
    final pos = await ref.read(assistantPositionProvider)();
    if (state.busy != true || !identical(state.turns, turns)) return;

    final started = DateTime.now();
    final tools = <String>[];
    final api = ref.read(apiClientProvider);
    final analytics = ref.read(analyticsProvider);

    void bump() => state = state.copyWith(turns: List.of(state.turns));

    void finish({required bool ok, String? code}) {
      _stop();
      answer.done = true;
      state = state.copyWith(turns: List.of(state.turns), busy: false);
      if (ok) {
        analytics.track(
          Ev.assistantQuery,
          assistantQueryProps(
            toolsUsed: tools,
            latencyMs: DateTime.now().difference(started).inMilliseconds,
            ok: true,
          ),
        );
      } else {
        // The question never leaves the device; only the fact that it failed.
        analytics.track(Ev.error, {'code': code ?? 'ASSISTANT_UPSTREAM', 'screen': 'assistant'});
      }
    }

    _sub = api
        .chat(
          cityId,
          sessionId: sessionId,
          messages: wireMessages(turns.sublist(0, turns.length - 1)),
          context: chatContext(position: pos, locale: locale),
        )
        .listen(
      (ev) {
        answer.apply(ev);
        if (ev is ChatToolStarted && ev.name.isNotEmpty) tools.add(ev.name);
        switch (ev) {
          case ChatDone():
            finish(ok: true);
          case ChatError(:final code):
            finish(ok: false, code: code);
          default:
            bump();
        }
      },
      onError: (Object e) {
        answer.error = const ChatError('ASSISTANT_UPSTREAM', '');
        finish(ok: false, code: 'ASSISTANT_UPSTREAM');
      },
      onDone: () {
        // A stream that ends without `done` still has to release the input.
        if (state.busy) finish(ok: answer.error == null);
      },
      cancelOnError: true,
    );
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);
