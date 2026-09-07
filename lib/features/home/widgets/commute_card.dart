import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/models.dart';
import '../../../core/providers.dart';
import '../../../core/storage/favorites.dart';
import '../../../core/utils/commute.dart';
import '../../../core/utils/countdown.dart';
import '../../../core/utils/format.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../planner/planner_state.dart';
import '../../planner/widgets/itinerary_card.dart';

/// Casa ⇄ Trabajo: the next viable departure toward whichever end fits the
/// hour, with a countdown and a detour badge when an alert touches the route.
/// Only rendered when both favourites exist.
class CommuteCard extends ConsumerStatefulWidget {
  const CommuteCard({super.key, required this.cityId});
  final String cityId;

  @override
  ConsumerState<CommuteCard> createState() => _CommuteCardState();
}

class _CommuteCardState extends ConsumerState<CommuteCard> {
  /// Set once the user inverts by hand; until then the hour decides.
  CommuteDirection? _override;
  late DateTime _now = DateTime.now();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final favs = ref.watch(favoritesProvider.notifier);
    ref.watch(favoritesProvider);
    final home = favs.ofKind(widget.cityId, FavoriteKind.home);
    final work = favs.ofKind(widget.cityId, FavoriteKind.work);

    final direction = _override ?? defaultCommuteDirection(_now);
    final ends = commuteEndpoints(direction, home: home, work: work);
    if (ends == null) return const SizedBox.shrink();

    final from = ends.from.toPlace();
    final to = ends.to.toPlace();
    final query = CommuteQuery(widget.cityId, from, to, direction);
    final plan = ref.watch(commutePlanProvider(query));
    final alerts = ref.watch(alertsProvider(widget.cityId)).asData?.value ?? const <TransitAlert>[];

    final title = direction == CommuteDirection.toWork ? l10n.commuteToWork : l10n.commuteToHome;
    final icon = direction == CommuteDirection.toWork ? Icons.work_rounded : Icons.home_rounded;

    void open() {
      final planner = ref.read(plannerProvider.notifier);
      planner.setFrom(from);
      planner.setTo(to);
      context.go('/${widget.cityId}/plan');
    }

    final itinerary = plan.asData?.value.itineraries
        .where((i) => !leaveState(i.startTime, _now).departed)
        .firstOrNull;
    final detour = itinerary == null ? const <TransitAlert>[] : commuteAlerts(itinerary, alerts);

    return Card(
      key: const ValueKey('commute-card'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('$title · ${ends.to.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    key: const ValueKey('commute-invert'),
                    tooltip: l10n.commuteInvert,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.swap_vert_rounded, size: 20),
                    onPressed: () => setState(() => _override =
                        direction == CommuteDirection.toWork
                            ? CommuteDirection.toHome
                            : CommuteDirection.toWork),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              plan.when(
                loading: () => const _CommuteSkeleton(),
                error: (_, _) => Text(l10n.commuteNoPlan,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                data: (_) {
                  if (itinerary == null) {
                    return Text(l10n.commuteNoPlan,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant));
                  }
                  final leave = leaveState(itinerary.startTime, _now);
                  final firstTransit = itinerary.transitLegs.firstOrNull;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (firstTransit?.route != null) ...[
                            RouteChip(firstTransit!.route),
                            const SizedBox(width: 8),
                          ],
                          LeaveByLabel(leave),
                          const Spacer(),
                          Text(
                            '${formatClock(itinerary.startTime, locale)} – ${formatClock(itinerary.endTime, locale)}',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      if (detour.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          key: const ValueKey('commute-detour'),
                          children: [
                            Icon(Icons.report_problem_rounded, size: 16, color: context.semantic.disruption),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(l10n.commuteDetour,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w700, color: context.semantic.disruption)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommuteSkeleton extends StatelessWidget {
  const _CommuteSkeleton();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 64,
            height: 20,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 90,
            height: 16,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      );
}
