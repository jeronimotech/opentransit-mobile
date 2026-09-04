import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/models.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/generated/app_localizations.dart';

/// "Mensajes de interés": severity-sorted, dismissible, capped impressions.
class AlertCarousel extends ConsumerStatefulWidget {
  const AlertCarousel({super.key, required this.cityId});
  final String cityId;

  @override
  ConsumerState<AlertCarousel> createState() => _AlertCarouselState();
}

class _AlertCarouselState extends ConsumerState<AlertCarousel> {
  final _page = PageController(viewportFraction: 0.94);
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final all = ref.watch(alertsProvider(widget.cityId)).asData?.value ?? const <TransitAlert>[];
    final imp = ref.watch(alertImpressionsProvider.notifier);
    ref.watch(alertImpressionsProvider); // rebuild on dismiss
    final visible = [...all.where((a) => imp.shouldShow(a.id))]
      ..sort((a, b) => b.severity.index.compareTo(a.severity.index));
    final shown = visible.take(5).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    for (final a in shown) {
      imp.recordImpression(a.id);
    }
    final idx = _index.clamp(0, shown.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(l10n.messagesOfInterest,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            TextButton(onPressed: () => context.go('/${widget.cityId}/alerts'), child: Text(l10n.seeAll)),
          ],
        ),
        SizedBox(
          height: 108,
          child: PageView.builder(
            controller: _page,
            itemCount: shown.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final a = shown[i];
              final accent = switch (a.severity) {
                AlertSeverity.severe => Colors.red.shade700,
                AlertSeverity.warning => Colors.orange.shade800,
                AlertSeverity.info => Colors.blue.shade700,
              };
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () async {
                      final url = a.url;
                      if (url != null && url.isNotEmpty) {
                        final uri = Uri.tryParse(url);
                        if (uri != null) {
                          try {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                            return;
                          } catch (_) {}
                        }
                      }
                      if (context.mounted) context.go('/${widget.cityId}/alerts');
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(width: 5, color: accent),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    alertIcon(a.severity, size: 18),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(a.header, maxLines: 2, overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                    ),
                                    IconButton(
                                      key: ValueKey('dismiss-${a.id}'),
                                      tooltip: l10n.dismiss,
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () => imp.dismiss(a.id),
                                    ),
                                  ],
                                ),
                                if (a.routes.isNotEmpty)
                                  Wrap(
                                    spacing: 4,
                                    children: [for (final r in a.routes.take(4)) RouteChip(r, dense: true)],
                                  )
                                else if (a.description != null)
                                  Text(a.description!, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (shown.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < shown.length; i++)
                  Container(
                    width: i == idx ? 16 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i == idx ? scheme.primary : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
