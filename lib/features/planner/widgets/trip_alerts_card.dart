import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Alerts that affect what is left of a trip in progress.
///
/// Asked for by TransMilenio against 1.16.0 (1.5): alerts were read when the trip was planned and
/// never again, so a closure published while the rider was on the first bus reached them as a
/// surprise at the transfer. One published after departure is marked as such — that is the one the
/// rider has not seen.
class TripAlertsCard extends StatefulWidget {
  const TripAlertsCard({super.key, required this.alerts, this.fresh = const {}});

  final List<TransitAlert> alerts;

  /// Ids the plan did not carry, shown with a "new" badge.
  final Set<String> fresh;

  @override
  State<TripAlertsCard> createState() => _TripAlertsCardState();
}

class _TripAlertsCardState extends State<TripAlertsCard> {
  final _open = <String>{};

  @override
  Widget build(BuildContext context) {
    if (widget.alerts.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        key: const ValueKey('go-trip-alerts'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.alertsOnYourTrip(widget.alerts.length),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          for (final a in widget.alerts)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: alertColor(context, a.severity).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: a.description == null
                      ? null
                      : () => setState(() => _open.contains(a.id) ? _open.remove(a.id) : _open.add(a.id)),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            alertIcon(a.severity, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(a.header,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                            ),
                            if (widget.fresh.contains(a.id)) ...[
                              const SizedBox(width: 8),
                              _Badge(text: l10n.alertNew, color: alertColor(context, a.severity)),
                            ],
                          ],
                        ),
                        if (a.description != null && _open.contains(a.id)) ...[
                          const SizedBox(height: 6),
                          Text(a.description!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
        child: Text(text,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
      );
}
