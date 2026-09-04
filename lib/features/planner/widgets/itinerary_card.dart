import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/utils/colors.dart';
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
                        softWrap: false,
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
              // Meta row wraps instead of overflowing on narrow screens.
              Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
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
