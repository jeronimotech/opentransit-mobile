import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/utils/format.dart';
import '../../core/utils/geo.dart';
import '../../l10n/generated/app_localizations.dart';
import '../planner/planner_state.dart';

/// Bottom sheet for one paid-parking zone: spaces as of when the operator
/// last counted (PIM's counts are hours old, and the sheet says so), whether a
/// car may park now and until when, the price, and two ways on: "Cómo llegar"
/// plans a trip to the zone, "Seguir en transporte" starts one from it.
Future<void> showCurbZoneSheet(BuildContext context, WidgetRef ref, String cityId, CurbZone zone) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => CurbZoneSheet(cityId: cityId, zone: zone),
    );

class CurbZoneSheet extends ConsumerWidget {
  const CurbZoneSheet({super.key, required this.cityId, required this.zone});
  final String cityId;
  final CurbZone zone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final z = zone;
    final tone = z.tone;
    final color = parkingColor(tone);
    final age = z.ageSeconds();
    final spaces = z.availableSpaces == null
        ? l10n.parkingUnknownSpaces
        : z.availableSpaces! <= 0
            ? l10n.parkingFull
            : z.totalSpaces != null
                ? l10n.parkingSpacesOf(z.availableSpaces!, z.totalSpaces!)
                : l10n.parkingSpaces(z.availableSpaces!);

    Widget stat(IconData icon, String text, {Color? c}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: c ?? scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Flexible(child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: c ?? scheme.onSurface))),
          ],
        );

    Place place() => Place(name: z.title, position: z.position);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.local_parking_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(z.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      Text(
                        [
                          l10n.parkingZone,
                          if (z.name != null && z.streetName != null) z.streetName!,
                          if (z.distanceMeters != null) formatDistance(z.distanceMeters!),
                        ].join(' · '),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                stat(Icons.local_parking_rounded, spaces,
                    c: tone == ParkingTone.full || tone == ParkingTone.closed ? scheme.outline : null),
                if (z.priceLabel != null) stat(Icons.payments_outlined, z.priceLabel!),
              ],
            ),
            const SizedBox(height: 8),
            if (z.allowed == false)
              Text(l10n.parkingNotNow, style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w700, fontSize: 12))
            else if (z.allowed == true)
              Text(
                z.nextChange == null ? l10n.parkingAllowedNow : '${l10n.parkingAllowedNow} · ${l10n.parkingUntil(formatClock(z.nextChange!, locale))}',
                style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: age == null ? scheme.outline : (age > 900 ? Colors.orange.shade800 : Colors.green.shade600), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(
                  age == null ? l10n.parkingNoCount : formatUpdatedAgo(age, l10n),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('parking-directions'),
                    onPressed: () {
                      ref.read(plannerProvider.notifier).setTo(place());
                      Navigator.of(context).pop();
                      context.go('/$cityId/plan');
                    },
                    icon: const Icon(Icons.directions_rounded),
                    label: Text(l10n.howToGetThere),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('parking-continue'),
                    onPressed: () {
                      ref.read(plannerProvider.notifier).setFrom(place());
                      Navigator.of(context).pop();
                      context.go('/$cityId/plan');
                    },
                    icon: const Icon(Icons.directions_bus_rounded, size: 18),
                    label: Text(l10n.parkingContinueByTransit, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
