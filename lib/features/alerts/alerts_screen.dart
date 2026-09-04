import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../l10n/generated/app_localizations.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key, required this.cityId});
  final String cityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final alerts = ref.watch(alertsProvider(cityId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.alerts)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(alertsProvider(cityId).future),
        child: alerts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(alertsProvider(cityId))),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: [SizedBox(height: 300, child: EmptyView(icon: Icons.notifications_none, message: l10n.noAlerts))]);
            }
            final sorted = [...list]..sort((a, b) => b.severity.index.compareTo(a.severity.index));
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: sorted.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _AlertCard(cityId: cityId, alert: sorted[i]),
            );
          },
        ),
      ),
    );
  }
}

class _AlertCard extends StatefulWidget {
  const _AlertCard({required this.cityId, required this.alert});
  final String cityId;
  final TransitAlert alert;
  @override
  State<_AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<_AlertCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final a = widget.alert;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final accent = switch (a.severity) {
      AlertSeverity.severe => Colors.red.shade700,
      AlertSeverity.warning => Colors.orange.shade800,
      AlertSeverity.info => Colors.blue.shade700,
    };
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _open = !_open),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        alertIcon(a.severity),
                        const SizedBox(width: 10),
                        Expanded(child: Text(a.header, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                        Icon(_open ? Icons.expand_less : Icons.expand_more, color: scheme.outline),
                      ],
                    ),
                    if (a.description != null) ...[
                      const SizedBox(height: 8),
                      Text(a.description!, maxLines: _open ? null : 2, overflow: _open ? null : TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                    if (a.routes.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final r in a.routes)
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => context.push('/${widget.cityId}/routes/${Uri.encodeComponent(r.id)}'),
                              child: RouteChip(r, dense: true),
                            ),
                        ],
                      ),
                    ],
                    if (a.start != null || a.end != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        [
                          if (a.start != null) formatDateShort(a.start!, locale),
                          if (a.end != null) formatDateShort(a.end!, locale),
                        ].join(' → '),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.outline),
                      ),
                    ],
                    if (_open && a.effect != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('${a.cause ?? ''} · ${a.effect}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.outline)),
                      ),
                    if (_open && a.routes.isEmpty && a.routeIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('${l10n.affectedRoutes}: ${a.routeIds.join(', ')}', style: Theme.of(context).textTheme.labelSmall),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
