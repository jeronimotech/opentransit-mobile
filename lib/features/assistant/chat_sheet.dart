import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import 'assistant_labels.dart';
import 'chat_controller.dart';
import 'chat_card_view.dart';

/// The assistant, phase 1: text.
///
/// Two rules shape this sheet. A card lands before the prose, so a useful
/// answer is on screen while the sentence is still being written. And nothing
/// typed here is ever tracked: the analytics event carries which tools ran and
/// how long it took, never the question.
Future<void> showAssistantSheet(BuildContext context, String cityId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => AssistantSheet(cityId: cityId),
  );
}

class AssistantSheet extends ConsumerStatefulWidget {
  const AssistantSheet({super.key, required this.cityId});
  final String cityId;

  @override
  ConsumerState<AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends ConsumerState<AssistantSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // The conversation lives above the sheet, so reopening keeps the thread;
    // a different city starts a new one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(chatProvider.notifier).open(widget.cityId);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _ask(String text) {
    if (text.trim().isEmpty) return;
    _input.clear();
    final locale = Localizations.localeOf(context).languageCode;
    ref.read(chatProvider.notifier).ask(widget.cityId, text, locale: locale);
    _focus.unfocus();
    _scrollToEnd();
  }

  /// Confirms first, because the thread is only in memory: once cleared there
  /// is nowhere to get it back from.
  Future<void> _newConversation() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('assistant-new-confirm'),
        icon: const Icon(Icons.add_comment_rounded),
        content: Text(l10n.assistantNewConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.assistantNewConfirmCta),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _input.clear();
    ref.read(chatProvider.notifier).newConversation();
    _focus.unfocus();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final chat = ref.watch(chatProvider);
    final city = ref.watch(cityProvider(widget.cityId)).asData?.value;
    ref.listen(chatProvider, (_, _) => _scrollToEnd());

    // Leave room for the keyboard; the list keeps the last turn in view.
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height * 0.82;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.forum_rounded, color: scheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.assistantTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('assistant-new'),
                    tooltip: l10n.assistantNewConversation,
                    icon: const Icon(Icons.add_comment_outlined),
                    // Disabled on an empty chat: there is nothing to reset, and
                    // a live button that does nothing reads as broken.
                    onPressed: chat.isEmpty ? null : _newConversation,
                  ),
                  IconButton(
                    tooltip: l10n.assistantClose,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            if (chat.noticePending && city != null)
              _Notice(text: l10n.assistantNotice(city.config.assistant.label)),
            Expanded(
              child: chat.isEmpty
                  ? _Intro(onPick: _ask)
                  : ListView.separated(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: chat.turns.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (_, i) {
                        final turn = chat.turns[i];
                        return turn.isUser
                            ? _UserBubble(text: turn.text)
                            : _AnswerView(turn: turn, cityId: widget.cityId);
                      },
                    ),
            ),
            _Composer(
              controller: _input,
              focus: _focus,
              busy: chat.busy,
              onSubmit: _ask,
              onStop: () => ref.read(chatProvider.notifier).cancel(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        text,
        key: const ValueKey('assistant-notice'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.onPick});
  final void Function(String) onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final suggestions = [
      l10n.assistantSuggestion1,
      l10n.assistantSuggestion2,
      l10n.assistantSuggestion3,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      children: [
        Text(
          l10n.assistantIntro,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        for (final s in suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                key: ValueKey('assistant-suggestion-${suggestions.indexOf(s)}'),
                borderRadius: BorderRadius.circular(14),
                onTap: () => onPick(s),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(
                        Icons.north_east_rounded,
                        size: 16,
                        color: scheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(text, style: TextStyle(color: scheme.onPrimary)),
        ),
      ),
    );
  }
}

class _AnswerView extends ConsumerWidget {
  const _AnswerView({required this.turn, required this.cityId});
  final ChatTurn turn;
  final String cityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final city = ref.watch(cityProvider(cityId)).asData?.value;
    final waiting = turn.text.isEmpty && turn.error == null && !turn.done;

    // The reply arrives a word at a time; a live region is what makes a screen
    // reader read it out instead of leaving a blind user waiting in silence.
    return Semantics(
      liveRegion: true,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (city != null)
            for (final card in turn.cards) ChatCardView(card: card, city: city),
          if (turn.tool != null)
            _Thinking(label: assistantToolLabel(turn.tool!, l10n)),
          if (turn.error != null)
            _ErrorBox(text: assistantErrorText(turn.error!.code, l10n))
          else if (turn.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: SelectableText(
                turn.text.trimRight(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
            )
          else if (waiting && turn.tool == null && turn.cards.isEmpty)
            _Thinking(label: l10n.assistantThinking),
        ],
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            key: const ValueKey('assistant-thinking'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('assistant-error'),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: scheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({
    required this.controller,
    required this.focus,
    required this.busy,
    required this.onSubmit,
    required this.onStop,
  });
  final TextEditingController controller;
  final FocusNode focus;
  final bool busy;
  final void Function(String) onSubmit;
  final VoidCallback onStop;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final canSend = widget.controller.text.trim().isNotEmpty && !widget.busy;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('assistant-input'),
              controller: widget.controller,
              focusNode: widget.focus,
              maxLength: 300,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onChanged: (_) => setState(() {}),
              onSubmitted: widget.busy ? null : widget.onSubmit,
              decoration: InputDecoration(
                counterText: '',
                hintText: l10n.assistantPlaceholder,
                filled: true,
                fillColor: scheme.surfaceContainerHigh,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            key: const ValueKey('assistant-send'),
            tooltip: widget.busy ? l10n.assistantStop : l10n.assistantSend,
            onPressed: widget.busy
                ? widget.onStop
                : canSend
                ? () => widget.onSubmit(widget.controller.text)
                : null,
            icon: Icon(
              widget.busy ? Icons.stop_rounded : Icons.arrow_upward_rounded,
            ),
          ),
        ],
      ),
    );
  }
}
