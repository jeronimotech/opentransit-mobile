import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics_event.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/utils/countdown.dart';
import '../../core/utils/fare.dart';
import '../../core/utils/format.dart';
import '../../core/utils/scenarios.dart';
import '../../core/widgets/common.dart';
import '../../l10n/generated/app_localizations.dart';
import 'planner_state.dart';
import 'widgets/itinerary_card.dart';

/// Flat sort orders offered in the "Ordenar" menu; `null` = grouped by
/// scenario (the default, Lote 1).
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
      ItinerarySort.cheapest => cmp(itineraryCost(a, city), itineraryCost(b, city), ia, ib) != 0
          ? cmp(itineraryCost(a, city), itineraryCost(b, city), ia, ib)
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
  /// `null` → grouped by scenario.
  ItinerarySort? _sort;
  late DateTime _now = DateTime.now();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Countdowns tick every 15 s; departed cards demote as time passes.
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _open(PlanResponse plan, Itinerary it, {required String scenario}) {
    final originalIndex = plan.itineraries.indexOf(it);
    ref.read(analyticsProvider).track(Ev.itinerarySelect, {
      'index': originalIndex,
      'source': it.source ?? 'primary',
      'scenario': scenario,
      'modes': it.modesUsed,
      'durationSeconds': it.durationSeconds,
      'transfers': it.transfers,
      'fareAmount': fareFor(it, ref.read(currentCityProvider))?.amount,
      'routeIds': [for (final l in it.legs) if (l.route != null) l.route!.id],
    });
    context.push('/${widget.cityId}/itinerary/$originalIndex');
  }

  Future<void> _replan() => ref.read(plannerProvider.notifier).plan(widget.cityId);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(plannerProvider);
    final city = ref.watch(currentCityProvider);
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
              await _replan();
            },
          ),
          PopupMenuButton<ItinerarySort?>(
            key: const ValueKey('sort-menu'),
            tooltip: l10n.orderMenu,
            icon: const Icon(Icons.sort_rounded),
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (context) => [
              CheckedPopupMenuItem<ItinerarySort?>(
                key: const ValueKey('sort-scenario'),
                value: null,
                checked: _sort == null,
                child: Text(l10n.sortByScenario),
              ),
              const PopupMenuDivider(),
              for (final o in ItinerarySort.values)
                CheckedPopupMenuItem<ItinerarySort?>(
                  key: ValueKey('sort-${o.name}'),
                  value: o,
                  checked: _sort == o,
                  child: Text(_label(o, l10n)),
                ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
              error: (e, _) => ErrorView(error: e, onRetry: _replan),
              data: (plan) {
                if (plan.itineraries.isEmpty) {
                  return EmptyView(icon: Icons.alt_route, message: l10n.noItineraries);
                }
                final header = Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.time == null
                              ? l10n.now
                              : '${s.arriveBy ? l10n.arriveBy : l10n.departAt} ${formatDateShort(s.time!, locale)}',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                      if (departedCount(plan.itineraries, _now) >= 2)
                        ActionChip(
                          key: const ValueKey('refresh-results'),
                          avatar: const Icon(Icons.refresh_rounded, size: 16),
                          label: Text(l10n.refreshResults),
                          visualDensity: VisualDensity.compact,
                          onPressed: _replan,
                        ),
                    ],
                  ),
                );
                final sort = _sort;
                if (sort != null) {
                  final sorted = demoteDeparted(sortItineraries(plan.itineraries, sort, city: city), _now);
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: sorted.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      if (i == 0) return header;
                      final it = sorted[i - 1];
                      return ItineraryCard(
                        itinerary: it,
                        highlighted: i == 1,
                        now: _now,
                        onTap: () => _open(plan, it, scenario: sort.name),
                      );
                    },
                  );
                }
                final groups = groupByScenario(plan.itineraries, city: city);
                return ListView(
                  key: const ValueKey('results-scenarios'),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    header,
                    for (final g in groups) ...[
                      _ScenarioSection(
                        group: g,
                        now: _now,
                        onOpen: (it) => _open(plan, it, scenario: g.scenario.name),
                      ),
                    ],
                  ],
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

String scenarioLabel(Scenario s, AppLocalizations l10n) => switch (s) {
      Scenario.fastest => l10n.scenarioFastest,
      Scenario.lessWalking => l10n.scenarioLessWalking,
      Scenario.fewerTransfers => l10n.scenarioFewerTransfers,
      Scenario.cheapest => l10n.scenarioCheapest,
      Scenario.bike => l10n.scenarioBike,
      Scenario.onDemand => l10n.scenarioOnDemand,
    };

IconData scenarioIcon(Scenario s) => switch (s) {
      Scenario.fastest => Icons.bolt_rounded,
      Scenario.lessWalking => Icons.directions_walk_rounded,
      Scenario.fewerTransfers => Icons.swap_horiz_rounded,
      Scenario.cheapest => Icons.savings_outlined,
      Scenario.bike => Icons.pedal_bike_rounded,
      Scenario.onDemand => Icons.local_taxi_rounded,
    };

/// One collapsible scenario: title, the best itinerary as a full card and
/// the rest as one-line rows. Departed options sink to the bottom.
class _ScenarioSection extends StatefulWidget {
  const _ScenarioSection({required this.group, required this.now, required this.onOpen});
  final ScenarioGroup group;
  final DateTime now;
  final void Function(Itinerary) onOpen;

  @override
  State<_ScenarioSection> createState() => _ScenarioSectionState();
}

class _ScenarioSectionState extends State<_ScenarioSection> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final g = widget.group;
    final ordered = demoteDeparted(g.all, widget.now);
    final best = ordered.first;
    final rest = ordered.skip(1).toList();
    return Column(
      key: ValueKey('scenario-${g.scenario.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
            child: Row(
              children: [
                Icon(scenarioIcon(g.scenario), size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                Text(scenarioLabel(g.scenario, l10n),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                if (rest.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(l10n.moreOptionsCount(rest.length),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
                const Spacer(),
                Icon(_open ? Icons.expand_less : Icons.expand_more, size: 20, color: scheme.outline),
              ],
            ),
          ),
        ),
        if (_open) ...[
          ItineraryCard(
            itinerary: best,
            highlighted: g.scenario == Scenario.fastest,
            now: widget.now,
            onTap: () => widget.onOpen(best),
          ),
          for (final it in rest)
            ItineraryRow(itinerary: it, now: widget.now, onTap: () => widget.onOpen(it)),
        ],
      ],
    );
  }
}
