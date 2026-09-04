import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/utils/colors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/geo.dart';
import '../../core/utils/rental.dart';
import '../../l10n/generated/app_localizations.dart';
import '../planner/planner_state.dart';

/// Bottom sheet for one docking station: availability by type, freshness,
/// "Cómo llegar" (plan to it) and the network's app hand-off. Works for any
/// network: name, colour and links come from `city.mobility.bikeShare[]`.
Future<void> showRentalStationSheet(
  BuildContext context,
  WidgetRef ref,
  String cityId,
  RentalStation station,
) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => RentalStationSheet(cityId: cityId, station: station),
    );

class RentalStationSheet extends ConsumerWidget {
  const RentalStationSheet({super.key, required this.cityId, required this.station});
  final String cityId;
  final RentalStation station;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final city = ref.watch(cityProvider(cityId)).asData?.value;
    // Fresher detail (vehicle types) when the API answers; else what we have.
    final detail = ref.watch(rentalStationProvider(CityKey(cityId, station.id))).asData?.value;
    final s = detail ?? station;
    final network = s.network ?? city?.mobility.network(s.networkId);
    final color = colorFromHex(network?.color, fallback: const Color(0xFF00A859));
    final age = s.ageSeconds();
    final appLink = network == null ? null : rentalAppLink(network);

    Widget stat(IconData icon, String text, {Color? c}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: c ?? scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: c ?? scheme.onSurface)),
          ],
        );

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
                  child: Icon(Icons.pedal_bike_rounded, color: onColor(color)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      Text(
                        [
                          network?.name ?? l10n.rentalStation,
                          if (s.distanceMeters != null) formatDistance(s.distanceMeters!),
                        ].join(' · '),
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
                stat(Icons.pedal_bike, l10n.bikesAvailable(s.vehiclesAvailable ?? 0),
                    c: (s.vehiclesAvailable ?? 0) == 0 ? scheme.outline : null),
                if ((s.ebikesAvailable ?? 0) > 0) stat(Icons.electric_bike, l10n.ebikesShort(s.ebikesAvailable!)),
                stat(Icons.local_parking_rounded, l10n.docksAvailable(s.docksAvailable ?? 0),
                    c: (s.docksAvailable ?? 0) == 0 ? scheme.outline : null),
              ],
            ),
            if (s.vehicleTypesAvailable.any((t) => (t.count ?? 0) > 0)) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final t in s.vehicleTypesAvailable)
                    if ((t.count ?? 0) > 0)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(t.isElectric ? Icons.electric_bike : Icons.pedal_bike, size: 14),
                        label: Text('${t.name ?? t.id} · ${t.count}'),
                      ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            if (!s.isRenting || !s.isInstalled)
              Text(l10n.rentalNotRenting, style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w700, fontSize: 12))
            else if (!s.isReturning)
              Text(l10n.rentalNotReturning, style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w700, fontSize: 12)),
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: age == null ? scheme.outline : (age > 180 ? Colors.orange.shade800 : Colors.green.shade600), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(
                  age == null ? (network == null ? '' : l10n.noRentalData(network.name)) : formatUpdatedAgo(age, l10n),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('rental-directions'),
                    onPressed: () {
                      ref.read(plannerProvider.notifier).setTo(Place(
                          name: s.name, position: s.position, rentalStationId: s.id));
                      Navigator.of(context).pop();
                      context.go('/$cityId/plan');
                    },
                    icon: const Icon(Icons.directions_rounded),
                    label: Text(l10n.howToGetThere),
                  ),
                ),
                if (appLink != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('rental-open-app'),
                      onPressed: () async {
                        try {
                          await launchUrl(appLink, mode: LaunchMode.externalApplication);
                        } catch (_) {}
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(l10n.openApp(network!.name), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
