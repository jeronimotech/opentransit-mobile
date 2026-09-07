import 'package:flutter/material.dart';

import '../../../core/theme/semantic_colors.dart';
import '../../../core/utils/fare.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/go_trip.dart';
import '../../../l10n/generated/app_localizations.dart';

/// End-of-trip receipt: what the trip actually took against what was planned,
/// plus the money and the CO₂ it saved against driving.
class TripReceiptSheet extends StatelessWidget {
  const TripReceiptSheet({super.key, required this.receipt});
  final TripReceipt receipt;

  static Future<void> show(BuildContext context, TripReceipt receipt) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => TripReceiptSheet(receipt: receipt),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final sem = context.semantic;
    final locale = Localizations.localeOf(context).toString();
    final r = receipt;
    final over = r.deltaSeconds > 60;
    final under = r.deltaSeconds < -60;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(r.completed ? Icons.check_circle_rounded : Icons.flag_rounded,
                    color: r.completed ? sem.live : scheme.outline),
                const SizedBox(width: 10),
                Text(l10n.goReceiptTitle,
                    key: const ValueKey('receipt-title'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: l10n.goReceiptPlanned,
                    value: formatDuration(r.plannedSeconds, l10n),
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: l10n.goReceiptActual,
                    value: formatDuration(r.actualSeconds, l10n),
                    color: over ? sem.disruption : (under ? sem.live : null),
                    trailing: over
                        ? '+${formatDuration(r.deltaSeconds, l10n)}'
                        : under
                            ? '−${formatDuration(-r.deltaSeconds, l10n)}'
                            : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _Metric(label: l10n.goReceiptDistance, value: formatDistance(r.distanceMeters))),
                Expanded(
                  child: _Metric(
                    label: l10n.goReceiptCost,
                    value: r.fare?.amount == null
                        ? '—'
                        : formatMoney(r.fare!.amount!, r.fare!.currency, locale),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Metric(
              label: l10n.goReceiptCo2,
              value: _formatGrams(r.co2SavedGrams),
              color: sem.live,
              icon: Icons.eco_rounded,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('receipt-close'),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.goReceiptClose),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatGrams(int g) =>
      g >= 1000 ? '${(g / 1000).toStringAsFixed(1)} kg' : '$g g';
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color, this.trailing, this.icon});
  final String label;
  final String value;
  final Color? color;
  final String? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 14, color: color ?? scheme.onSurfaceVariant), const SizedBox(width: 4)],
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800, color: color)),
            if (trailing != null) ...[
              const SizedBox(width: 6),
              Text(trailing!,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
            ],
          ],
        ),
      ],
    );
  }
}
