import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../l10n/generated/app_localizations.dart';
import 'planner_state.dart';
import 'widgets/itinerary_card.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key, required this.cityId});
  final String cityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(plannerProvider);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final result = s.result;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.results),
        actions: [
          IconButton(
            tooltip: l10n.reverseTrip,
            icon: const Icon(Icons.swap_vert),
            onPressed: () async {
              ref.read(plannerProvider.notifier).swap();
              await ref.read(plannerProvider.notifier).plan(cityId);
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Icon(Icons.trip_origin, size: 14, color: scheme.primary),
                const SizedBox(width: 6),
                Expanded(child: Text(s.from?.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                Icon(Icons.arrow_forward, size: 16, color: scheme.outline),
                const SizedBox(width: 6),
                Expanded(child: Text(s.to?.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
          ),
        ),
      ),
      body: result == null
          ? EmptyView(icon: Icons.alt_route, message: l10n.noItineraries)
          : result.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                error: e,
                onRetry: () => ref.read(plannerProvider.notifier).plan(cityId),
              ),
              data: (plan) {
                if (plan.itineraries.isEmpty) {
                  return EmptyView(icon: Icons.alt_route, message: l10n.noItineraries);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: plan.itineraries.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          s.time == null
                              ? l10n.now
                              : '${s.arriveBy ? l10n.arriveBy : l10n.departAt} ${formatDateShort(s.time!, locale)}',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      );
                    }
                    final idx = i - 1;
                    return ItineraryCard(
                      itinerary: plan.itineraries[idx],
                      highlighted: idx == 0,
                      onTap: () => context.push('/$cityId/itinerary/$idx'),
                    );
                  },
                );
              },
            ),
    );
  }
}
