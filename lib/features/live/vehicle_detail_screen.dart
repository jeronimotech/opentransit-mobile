import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/utils/colors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/polyline.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/transit_map.dart';
import '../../l10n/generated/app_localizations.dart';

class VehicleDetailScreen extends ConsumerWidget {
  const VehicleDetailScreen({super.key, required this.cityId, required this.vehicleId});
  final String cityId;
  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final key = CityKey(cityId, vehicleId);
    final detail = ref.watch(vehicleDetailProvider(key));
    // Follow the live position if the stream is active.
    final live = ref.watch(liveVehiclesProvider(cityId)).asData?.value.vehicles[vehicleId];
    final scheme = Theme.of(context).colorScheme;

    return detail.when(
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: ErrorView(error: e, onRetry: () => ref.invalidate(vehicleDetailProvider(key)))),
      data: (d) {
        final v = live ?? d.vehicle;
        final color = colorFromHex(d.route?.color, fallback: componentColor(v.component));
        final shape = d.shape == null ? const <LatLng>[] : decodeGeometry(d.shape!);
        final lines = [
          if (shape.isNotEmpty) MapLine(id: 'shape', points: shape, color: color.withValues(alpha: 0.6), width: 4),
          if (d.historyPoints.length > 1) MapLine(id: 'hist', points: d.historyPoints, color: scheme.onSurface, width: 3, dashed: true),
        ];
        final markers = [
          MapPoint(id: v.id, position: v.position, color: color, radius: 11, strokeWidth: 3, label: v.routeShortName ?? ''),
          if (d.nextStop != null) MapPoint(id: d.nextStop!.id, position: d.nextStop!.position, color: Colors.white, strokeColor: color, strokeWidth: 3, radius: 6),
        ];
        final age = v.timestamp == null ? null : DateTime.now().difference(v.timestamp!).inSeconds;
        final delay = formatDelay(d.delaySeconds, l10n);

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                RouteChip(d.route),
                const SizedBox(width: 10),
                Expanded(child: Text(v.label ?? v.id, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: TransitMap(
                  initialCenter: v.position,
                  initialZoom: 14,
                  lines: lines,
                  markers: markers,
                  fitTo: shape.isEmpty ? [v.position] : shape,
                  fitPadding: const EdgeInsets.all(40),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const LiveBadge(),
                        if (age != null) ...[
                          const SizedBox(width: 8),
                          Text(l10n.updatedAgo(age.clamp(0, 9999)), style: Theme.of(context).textTheme.labelSmall),
                        ],
                        const Spacer(),
                        if (delay != null)
                          Text(delay, style: TextStyle(fontWeight: FontWeight.w700, color: (d.delaySeconds ?? 0) > 60 ? Colors.orange.shade800 : Colors.green.shade700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (d.tripHeadsign != null) Text(l10n.towards(d.tripHeadsign!), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    if (d.nextStop != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.arrow_circle_right_outlined, color: color),
                        title: Text(d.nextStop!.name),
                        subtitle: Text(l10n.stop),
                        trailing: d.etaSeconds == null ? null : Text(l10n.inMinutes((d.etaSeconds! / 60).round()), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        onTap: () => context.push('/$cityId/stops/${Uri.encodeComponent(d.nextStop!.id)}'),
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (d.avgKmh != null) Chip(avatar: const Icon(Icons.speed, size: 16), label: Text('${d.avgKmh!.toStringAsFixed(0)} km/h'), visualDensity: VisualDensity.compact),
                        if (v.occupancy != null) Chip(avatar: const Icon(Icons.groups, size: 16), label: Text(_occupancy(v.occupancy!)), visualDensity: VisualDensity.compact),
                        if (!v.tripResolved) Chip(avatar: const Icon(Icons.help_outline, size: 16), label: Text(l10n.scheduled), visualDensity: VisualDensity.compact),
                      ],
                    ),
                    for (final a in d.alerts)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: alertIcon(a.severity, size: 20),
                        title: Text(a.header, maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () => context.go('/$cityId/alerts'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _occupancy(String o) => switch (o) {
      'EMPTY' => '○○○',
      'MANY_SEATS_AVAILABLE' => '●○○',
      'FEW_SEATS_AVAILABLE' => '●●○',
      'STANDING_ROOM_ONLY' || 'CRUSHED_STANDING_ROOM_ONLY' => '●●●',
      'FULL' || 'NOT_ACCEPTING_PASSENGERS' => '●●● !',
      _ => o,
    };
