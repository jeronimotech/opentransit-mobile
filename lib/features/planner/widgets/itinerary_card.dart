import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Summary card for one itinerary: leg chips, duration, times, transfers.
class ItineraryCard extends StatelessWidget {
  const ItineraryCard({super.key, required this.itinerary, this.onTap, this.highlighted = false});
  final Itinerary itinerary;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final scheme = Theme.of(context).colorScheme;
    final it = itinerary;
    final alerts = it.alerts;

    return Material(
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
                          _LegChip(it.legs[i]),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatDuration(it.durationSeconds, l10n),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
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
              Row(
                children: [
                  Icon(Icons.swap_horiz, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(l10n.transfersCount(it.transfers), style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(width: 12),
                  Icon(Icons.directions_walk, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(l10n.walkDistance(it.walkDistanceMeters), style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(width: 12),
                  Icon(Icons.payments_outlined, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  FareText(it),
                  const Spacer(),
                  if (alerts.isNotEmpty) ...[
                    alertIcon(alerts.first.severity, size: 16),
                    const SizedBox(width: 8),
                  ],
                  if (it.hasRealtime) const LiveBadge(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegChip extends StatelessWidget {
  const _LegChip(this.leg);
  final Leg leg;

  @override
  Widget build(BuildContext context) {
    if (leg.transit) return RouteChip(leg.route, dense: true);
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: '${modeLabel(leg.mode, l10n)} · ${formatDuration(leg.durationSeconds, l10n)}',
      child: RouteChip(null, dense: true, mode: leg.mode),
    );
  }
}
