import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/utils/colors.dart';
import '../../../core/utils/countdown.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Summary card for one itinerary: leg chips, duration, times, transfers and
/// the leave-by countdown ("Sal en 4 min"). Cards whose departure passed are
/// greyed (Lote 1).
class ItineraryCard extends StatelessWidget {
  const ItineraryCard({super.key, required this.itinerary, this.onTap, this.highlighted = false, this.now});
  final Itinerary itinerary;
  final VoidCallback? onTap;
  final bool highlighted;

  /// Reference instant for the countdown (defaults to the wall clock).
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final scheme = Theme.of(context).colorScheme;
    final it = itinerary;
    final alerts = it.alerts;
    final leave = leaveState(it.startTime, now ?? DateTime.now());

    return Opacity(
      opacity: leave.departed ? 0.55 : 1,
      child: Material(
        color: highlighted ? scheme.primaryContainer.withValues(alpha: 0.35) : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (var i = 0; i < it.legs.length; i++) ...[
                            if (i > 0) Icon(Icons.chevron_right, size: 16, color: scheme.outline),
                            LegChip(it.legs[i]),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (it.hasRealtime) ...[const LiveBadge(), const SizedBox(width: 8)],
                            Text(
                              formatDuration(it.durationSeconds, l10n),
                              softWrap: false,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
                            ),
                          ],
                        ),
                        Text(
                          '${formatClock(it.startTime, locale)} – ${formatClock(it.endTime, locale)}',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Meta row wraps instead of overflowing on narrow screens.
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    LeaveByLabel(leave),
                    _Meta(Icons.swap_horiz, l10n.transfersCount(it.transfers)),
                    _Meta(Icons.directions_walk, l10n.walkDistance(it.walkDistanceMeters)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.payments_outlined, size: 16, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        FareText(it),
                      ],
                    ),
                    if (alerts.isNotEmpty) alertIcon(alerts.first.severity, size: 16),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One-line row for the non-best itineraries of a scenario section: times,
/// duration, chips, countdown.
class ItineraryRow extends StatelessWidget {
  const ItineraryRow({super.key, required this.itinerary, this.onTap, this.now});
  final Itinerary itinerary;
  final VoidCallback? onTap;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final scheme = Theme.of(context).colorScheme;
    final it = itinerary;
    final leave = leaveState(it.startTime, now ?? DateTime.now());
    final transit = it.legs.where((l) => l.transit || l.isRental || l.isOnDemand).toList();
    return Opacity(
      opacity: leave.departed ? 0.55 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 74,
                child: Text(formatDuration(it.durationSeconds, l10n),
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, fontSize: 12)),
              ),
              // Route names vary in length (B10 … HF615): let the chips scroll
              // inside their slot instead of overflowing the row.
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: Row(
                    children: [
                      for (var i = 0; i < transit.length && i < 3; i++) ...[
                        if (i > 0) Icon(Icons.chevron_right, size: 14, color: scheme.outline),
                        LegChip(transit[i]),
                      ],
                      if (transit.length > 3) Text(' +${transit.length - 3}', style: Theme.of(context).textTheme.labelSmall),
                      if (transit.isEmpty) LegChip(it.legs.first),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${formatClock(it.startTime, locale)} – ${formatClock(it.endTime, locale)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                  LeaveByLabel(leave, dense: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Sal en 4 min" (green blip when live), "Sal ahora", "Ya salió".
class LeaveByLabel extends StatelessWidget {
  const LeaveByLabel(this.state, {super.key, this.dense = false});
  final LeaveState state;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sem = context.semantic;
    final scheme = Theme.of(context).colorScheme;
    final (text, color) = switch (state.kind) {
      LeaveKind.leaveIn => (l10n.leaveIn(state.minutes), sem.live),
      LeaveKind.leaveNow => (l10n.leaveNow, sem.disruption),
      LeaveKind.departed => (l10n.departed, scheme.outline),
    };
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(state.departed ? Icons.history_rounded : Icons.timer_outlined, size: dense ? 12 : 16, color: color),
            const SizedBox(width: 4),
            Text(text,
                key: ValueKey('leave-${state.kind.name}'),
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: dense ? 11 : 12)),
          ],
        ),
      ),
    );
  }
}

/// Chip for one leg: the route for transit, the network for shared bikes, the
/// provider for rides, the mode icon otherwise.
class LegChip extends StatelessWidget {
  const LegChip(this.leg, {super.key});
  final Leg leg;

  @override
  Widget build(BuildContext context) {
    if (leg.transit) return RouteChip(leg.route, dense: true);
    final l10n = AppLocalizations.of(context);
    final od = leg.onDemand;
    if (od != null) {
      final rec = od.recommended;
      final color = colorFromHex(rec?.color ?? '#455A64', fallback: const Color(0xFF455A64));
      return Tooltip(
        message: '${rec?.name ?? modeLabel(leg.mode, l10n)} · ${formatDuration(leg.durationSeconds, l10n)}',
        child: OnDemandChip(
          name: rec?.name ?? l10n.onDemandTaxi,
          color: color,
          dense: true,
          taxi: od.displayKind == 'taxi',
        ),
      );
    }
    final r = leg.rental;
    if (r != null) {
      return Tooltip(
        message: '${l10n.sharedBikeOf(r.networkName)} · ${formatDuration(leg.durationSeconds, l10n)}',
        child: RentalChip(
          name: r.networkName,
          color: colorFromHex(r.color, fallback: const Color(0xFF00A859)),
          dense: true,
          electric: r.isElectric,
        ),
      );
    }
    return Tooltip(
      message: '${modeLabel(leg.mode, l10n)} · ${formatDuration(leg.durationSeconds, l10n)}',
      child: RouteChip(null, dense: true, mode: leg.mode),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
