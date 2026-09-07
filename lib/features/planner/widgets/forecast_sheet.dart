import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/providers.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/geo.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../planner_state.dart';

/// "Cuándo salir": the next departures across the forecast window as a
/// timeline. Picking one re-plans at that time.
class ForecastSheet extends ConsumerWidget {
  const ForecastSheet({super.key, required this.cityId, required this.onPick});
  final String cityId;
  final void Function(DateTime departAt) onPick;

  static Future<void> show(BuildContext context, String cityId, void Function(DateTime) onPick) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => ForecastSheet(cityId: cityId, onPick: onPick),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final s = ref.watch(plannerProvider);
    if (s.from == null || s.to == null) return const SizedBox.shrink();

    final async = ref.watch(forecastProvider(ForecastQuery(
      cityId: cityId,
      from: s.from!,
      to: s.to!,
      modes: s.modes,
      onDemand: s.onDemand,
    )));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (context, controller) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(l10n.departuresSheetTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(forecastProvider(ForecastQuery(
                        cityId: cityId, from: s.from!, to: s.to!, modes: s.modes, onDemand: s.onDemand,
                      )))),
              data: (f) => f.isEmpty
                  ? EmptyView(icon: Icons.schedule, message: l10n.forecastEmpty)
                  : ListView.builder(
                      key: const ValueKey('forecast-list'),
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      itemCount: f.options.length,
                      itemBuilder: (context, i) => _ForecastRow(
                        option: f.options[i],
                        first: i == 0,
                        last: i == f.options.length - 1,
                        onTap: () {
                          Navigator.of(context).pop();
                          onPick(f.options[i].departAt);
                        },
                      ),
                    ),
            ),
          ),
          if (async.asData?.value.notes.isNotEmpty ?? false)
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.paddingOf(context).bottom + 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(async.asData!.value.notes.first.text ?? '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ForecastRow extends StatelessWidget {
  const _ForecastRow({required this.option, required this.first, required this.last, required this.onTap});
  final ForecastOption option;
  final bool first;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final sem = context.semantic;
    final locale = Localizations.localeOf(context).toString();
    final o = option;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                // Timeline rail.
                SizedBox(
                  width: 22,
                  child: Column(
                    children: [
                      Container(width: 2, height: 10, color: first ? Colors.transparent : scheme.outlineVariant),
                      Container(
                        width: o.recommended ? 14 : 10,
                        height: o.recommended ? 14 : 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: o.recommended ? scheme.primary : scheme.surface,
                          border: Border.all(color: o.recommended ? scheme.primary : scheme.outline, width: 2),
                        ),
                      ),
                      Container(width: 2, height: 10, color: last ? Colors.transparent : scheme.outlineVariant),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(formatClock(o.departAt, locale),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: o.recommended ? scheme.primary : null)),
                          const SizedBox(width: 8),
                          Text(l10n.forecastArrive(formatClock(o.arriveAt, locale)),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                          if (o.realtime) ...[const SizedBox(width: 8), const LiveBadge()],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(formatDuration(o.durationSeconds, l10n),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 10),
                          Icon(Icons.swap_horiz_rounded, size: 13, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 2),
                          Text('${o.transfers}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                          const SizedBox(width: 10),
                          Icon(Icons.directions_walk_rounded, size: 13, color: sem.walk),
                          const SizedBox(width: 2),
                          Text(formatDistance(o.walkMeters),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (o.recommended)
                  Container(
                    key: const ValueKey('forecast-recommended'),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(l10n.forecastRecommended,
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer)),
                  ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 18, color: scheme.outline),
              ],
            ),
          ),
        ),
        if (o.hasLongGap)
          Padding(
            key: const ValueKey('forecast-gap'),
            padding: const EdgeInsets.only(left: 34, bottom: 8),
            child: Row(
              children: [
                Icon(Icons.more_vert, size: 14, color: sem.disruption),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.forecastGap(formatClock(
                        o.departAt.add(Duration(seconds: o.gapAfterSeconds!)), locale)),
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: sem.disruption, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
