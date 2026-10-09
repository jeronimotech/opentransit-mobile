import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/utils/colors.dart';
import '../../core/widgets/common.dart';
import '../../l10n/generated/app_localizations.dart';

/// Help and reports.
///
/// Asked for by TransMilenio against 1.16.0 (1.16): the app had links to the operator's channels
/// and nothing that said what each one answers, no emergency line, and no way to report that the
/// app itself is wrong — "this stop is on the other side of the street", "this ramp is blocked".
/// A report about our own data is ours to receive, so it goes to our API, anonymously.
class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key, required this.cityId, this.stopId, this.routeId});

  final String cityId;

  /// Prefilled when the rider came from a stop or a route: the thing they were looking at is
  /// almost always the thing that is wrong.
  final String? stopId;
  final String? routeId;

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  final _message = TextEditingController();
  final _contact = TextEditingController();
  String _kind = 'wrong_info';
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).createReport(
            widget.cityId,
            kind: _kind,
            message: text,
            stopId: widget.stopId,
            routeId: widget.routeId,
            contact: _contact.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _sent = true;
        _sending = false;
      });
      _message.clear();
      _contact.clear();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.message;
      });
    } on Object {
      if (!mounted) return;
      // No network, or something we did not anticipate: the text is still in the field, so the
      // honest answer is "it did not go" rather than a message pretending to know why.
      setState(() {
        _sending = false;
        _error = AppLocalizations.of(context).reportFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final city = ref.watch(cityProvider(widget.cityId)).asData?.value;
    final services = city?.services ?? const <CityService>[];
    final emergency = [for (final s in services) if (s.emergency) s];
    final channels = [for (final s in services) if (!s.emergency) s];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpAndReports)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (emergency.isNotEmpty) ...[
            SectionTitle(l10n.emergency),
            for (final s in emergency)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Material(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    key: ValueKey('help-call-${s.id}'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => launchUrl(Uri(scheme: 'tel', path: s.phone)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(Icons.emergency_outlined, color: scheme.onErrorContainer),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.label,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w800, color: scheme.onErrorContainer)),
                                if (s.description != null)
                                  Text(s.description!,
                                      style: Theme.of(context).textTheme.bodySmall
                                          ?.copyWith(color: scheme.onErrorContainer)),
                              ],
                            ),
                          ),
                          Icon(Icons.call, color: scheme.onErrorContainer),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],

          // Reporting comes before the operator's channels: this is the one channel that reaches
          // the people who can fix the app's own data.
          SectionTitle(l10n.reportProblem),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.reportExplain,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final k in const ['wrong_info', 'barrier', 'other'])
                      ChoiceChip(
                        key: ValueKey('report-kind-$k'),
                        label: Text(switch (k) {
                          'wrong_info' => l10n.reportWrongInfo,
                          'barrier' => l10n.reportBarrier,
                          _ => l10n.reportOther,
                        }),
                        selected: _kind == k,
                        onSelected: (_) => setState(() => _kind = k),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('report-message'),
                  controller: _message,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: l10n.reportWhatHappened,
                    helperText: widget.stopId != null || widget.routeId != null
                        ? l10n.reportAttached(widget.stopId ?? widget.routeId!)
                        : null,
                  ),
                ),
                TextField(
                  key: const ValueKey('report-contact'),
                  controller: _contact,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: l10n.reportContactOptional,
                  ),
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error!, style: TextStyle(color: scheme.error)),
                  ),
                if (_sent)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      key: const ValueKey('report-sent'),
                      children: [
                        Icon(Icons.check_circle, color: scheme.primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(l10n.reportThanks)),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    key: const ValueKey('report-send'),
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(l10n.reportSend),
                  ),
                ),
              ],
            ),
          ),

          if (channels.isNotEmpty) ...[
            SectionTitle(l10n.supportChannels),
            for (final s in channels)
              ListTile(
                key: ValueKey('help-channel-${s.id}'),
                leading: Icon(iconByName(s.icon, fallback: Icons.open_in_new)),
                title: Text(s.label),
                subtitle: s.description == null ? null : Text(s.description!),
                trailing: Icon(s.isCall ? Icons.call : Icons.open_in_new, size: 18),
                onTap: () => s.isCall
                    ? launchUrl(Uri(scheme: 'tel', path: s.phone))
                    : launchUrl(Uri.parse(s.url), mode: LaunchMode.externalApplication),
              ),
          ],
        ],
      ),
    );
  }
}
