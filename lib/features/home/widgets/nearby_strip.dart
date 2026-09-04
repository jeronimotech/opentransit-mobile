import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/providers.dart';
import '../../../core/utils/geo.dart';
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
  });
  final String cityId;
  final List<Stop> stops;
  final bool loading;
  final void Function(Stop) onTap;
  final int max;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 112,
      child: loading && stops.isEmpty
          ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          : stops.isEmpty
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
                  itemCount: stops.length.clamp(0, max),
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _NearbyCard(cityId: cityId, stop: stops[i], onTap: () => onTap(stops[i])),
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
