import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/providers.dart';
import '../../../core/utils/colors.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/rental.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/generated/app_localizations.dart';

/// "Cerca de ti": horizontal cards for the nearest stops with their next two
/// departures (UX audit §A). Tapping a card centres the map and opens the stop.
class NearbyStrip extends StatelessWidget {
  const NearbyStrip({
    super.key,
    required this.cityId,
    required this.stops,
    required this.loading,
    required this.onTap,
    this.max = 6,
    this.rental = const [],
    this.onRentalTap,
    this.city,
  });
  final String cityId;
  final List<Stop> stops;
  final bool loading;
  final void Function(Stop) onTap;
  final int max;

  /// Nearest shared-bike stations (v1.2); the closest one gets a card.
  final List<RentalStation> rental;
  final void Function(RentalStation)? onRentalTap;
  final City? city;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final nearest = rental.firstOrNull;
    final network = nearest == null ? null : city?.mobility.network(nearest.networkId);
    return SizedBox(
      height: 112,
      child: loading && stops.isEmpty && nearest == null
          ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          : stops.isEmpty && nearest == null
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(l10n.noNearbyStops, style: TextStyle(color: scheme.onSurfaceVariant)),
                  ),
                )
              : ListView.separated(
                  key: const ValueKey('nearby-strip'),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: stops.length.clamp(0, max) + (nearest == null ? 0 : 1),
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    // The docking station card sits second so the nearest
                    // stop stays first; first when there are no stops.
                    final rentalAt = stops.isEmpty ? 0 : 1;
                    if (nearest != null && i == rentalAt) {
                      return _NearbyRentalCard(
                        station: nearest,
                        network: network,
                        onTap: () => onRentalTap?.call(nearest),
                      );
                    }
                    final si = nearest != null && i > rentalAt ? i - 1 : i;
                    return _NearbyCard(cityId: cityId, stop: stops[si], onTap: () => onTap(stops[si]));
                  },
                ),
    );
  }
}

class _NearbyCard extends ConsumerWidget {
  const _NearbyCard({required this.cityId, required this.stop, required this.onTap});
  final String cityId;
  final Stop stop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final board = ref.watch(boardProvider(CityKey(cityId, stop.id))).asData?.value;
    // Earliest two departures across every route at this stop.
    final times = <(BoardRow, BoardTime)>[
      for (final row in board?.rows ?? const <BoardRow>[])
        for (final t in row.next) (row, t),
    ]..sort((a, b) => a.$2.minutes.compareTo(b.$2.minutes));
    final next = times.take(2).toList();
    final subtitle = [
      stop.isStation ? l10n.station : l10n.stop,
      if (stop.distanceMeters != null) formatDistance(stop.distanceMeters!),
    ].join(' · ');
    return Semantics(
      button: true,
      label: '${stop.name}, $subtitle',
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            width: 200,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ComponentBadge(stop.component, isStation: stop.isStation, size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(stop.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            Text(subtitle, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (next.isEmpty)
                    Text(board == null ? '…' : l10n.noBoard,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11))
                  else
                    for (final (row, t) in next)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            RouteChip(row.route, dense: true),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                t.minutes <= 0 ? l10n.arrivingNow : l10n.minutesOnly(t.minutes),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: t.realtime ? Colors.green.shade700 : scheme.onSurface),
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nearest shared-bike station: icon in the network colour, name, distance
/// and "6 bicis · 13 puestos".
class _NearbyRentalCard extends StatelessWidget {
  const _NearbyRentalCard({required this.station, required this.network, required this.onTap});
  final RentalStation station;
  final BikeShareNetwork? network;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final color = colorFromHex(network?.color, fallback: const Color(0xFF00A859));
    final subtitle = [
      network?.name ?? l10n.rentalStation,
      if (station.distanceMeters != null) formatDistance(station.distanceMeters!),
    ].join(' · ');
    final avail = availabilitySummary(station, bikes: l10n.bikesShort, ebikes: l10n.ebikesShort, docks: l10n.docksShort);
    return Semantics(
      button: true,
      label: '${station.name}, $subtitle, $avail',
      child: Material(
        key: const ValueKey('nearby-rental'),
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            width: 200,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.pedal_bike_rounded, color: onColor(color), size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(station.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(Icons.pedal_bike, size: 14, color: (station.vehiclesAvailable ?? 0) > 0 ? color : scheme.outline),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(avail, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12,
                                color: (station.vehiclesAvailable ?? 0) > 0 ? scheme.onSurface : scheme.outline)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
