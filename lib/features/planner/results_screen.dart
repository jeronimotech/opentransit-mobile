import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/utils/fare.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../l10n/generated/app_localizations.dart';
import 'planner_state.dart';
import 'widgets/itinerary_card.dart';

/// Sort orders offered on the results screen (Maas-style chips).
enum ItinerarySort { fastest, fewerTransfers, lessWalking, cheapest, earliest }

/// Stable sort of itineraries by [sort]; ties keep the router's order.
List<Itinerary> sortItineraries(List<Itinerary> its, ItinerarySort sort, {City? city}) {
  final indexed = its.indexed.toList();
  int cmp(num a, num b, int ia, int ib) => a == b ? ia.compareTo(ib) : a.compareTo(b);
  indexed.sort((x, y) {
    final (ia, a) = x;
    final (ib, b) = y;
    return switch (sort) {
      ItinerarySort.fastest => cmp(a.durationSeconds, b.durationSeconds, ia, ib),
      ItinerarySort.fewerTransfers => cmp(a.transfers, b.transfers, ia, ib) != 0
          ? cmp(a.transfers, b.transfers, ia, ib)
          : cmp(a.durationSeconds, b.durationSeconds, ia, ib),
      ItinerarySort.lessWalking => cmp(a.walkDistanceMeters, b.walkDistanceMeters, ia, ib),
      ItinerarySort.cheapest => cmp(fareFor(a, city)?.amount ?? double.infinity, fareFor(b, city)?.amount ?? double.infinity, ia, ib) != 0
          ? cmp(fareFor(a, city)?.amount ?? double.infinity, fareFor(b, city)?.amount ?? double.infinity, ia, ib)
          : cmp(a.durationSeconds, b.durationSeconds, ia, ib),
      ItinerarySort.earliest => cmp(a.startTime.millisecondsSinceEpoch, b.startTime.millisecondsSinceEpoch, ia, ib),
    };
  });
  return [for (final (_, it) in indexed) it];
}

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key, required this.cityId});
  final String cityId;

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  ItinerarySort _sort = ItinerarySort.earliest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(plannerProvider);
    final city = ref.watch(currentCityProvider);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final result = s.result;
    final cityId = widget.cityId;

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
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final o in ItinerarySort.values) ...[
                      ChoiceChip(
                        key: ValueKey('sort-${o.name}'),
                        label: Text(_label(o, l10n)),
                        selected: _sort == o,
                        onSelected: (_) => setState(() => _sort = o),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ],
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
                final sorted = sortItineraries(plan.itineraries, _sort, city: city);
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: sorted.length + 1,
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
                    final it = sorted[i - 1];
                    final originalIndex = plan.itineraries.indexOf(it);
                    return ItineraryCard(
                      itinerary: it,
                      highlighted: i == 1,
                      onTap: () => context.push('/$cityId/itinerary/$originalIndex'),
                    );
                  },
                );
              },
            ),
    );
  }

  static String _label(ItinerarySort o, AppLocalizations l10n) => switch (o) {
        ItinerarySort.fastest => l10n.sortFastest,
        ItinerarySort.fewerTransfers => l10n.sortFewerTransfers,
        ItinerarySort.lessWalking => l10n.sortLessWalking,
        ItinerarySort.cheapest => l10n.sortCheapest,
        ItinerarySort.earliest => l10n.sortEarliest,
      };
}
