import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/utils/colors.dart';
import '../../core/utils/geo.dart';
import '../../core/utils/location.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/transit_map.dart';
import '../../l10n/generated/app_localizations.dart';
import '../planner/planner_state.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.cityId});
  final String cityId;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _mapKey = GlobalKey<TransitMapState>();
  LatLng? _center;
  double _zoom = 12;
  bool _locating = false;

  /// The blue dot is enabled only after the user asked for it, so the system
  /// permission prompt never appears uninvited on first launch.
  bool _showMyLocation = false;

  // Memoised overlay lists so the map only re-syncs when data really changed.
  List<Stop>? _lastStops;
  List<MapPoint> _stopPoints = const [];
  int _lastFrameSeq = -1;
  String _lastFrameKey = '';
  List<MapPoint> _vehiclePoints = const [];

  List<MapPoint> _stopsToPoints(List<Stop> stops) {
    if (identical(stops, _lastStops)) return _stopPoints;
    _lastStops = stops;
    return _stopPoints = [
      for (final s in stops)
        MapPoint(
          id: s.id,
          position: s.position,
          color: componentColor(s.component),
          radius: s.isStation ? 7 : 5,
          label: s.name,
        ),
    ];
  }

  /// Converts the live frame to map points. Real feeds carry ~6,000 buses, so
  /// beyond [_viewportCullAbove] vehicles only those near the camera are sent
  /// to the native map (radius shrinks as the user zooms in).
  static const _viewportCullAbove = 1500;

  List<MapPoint> _frameToPoints(VehicleFrame f, LatLng center, double zoom) {
    final cull = f.count > _viewportCullAbove;
    final zoomBucket = (zoom * 2).round();
    final key = cull ? '${f.seq}|$zoomBucket|${center.lat.toStringAsFixed(3)}|${center.lon.toStringAsFixed(3)}' : '${f.seq}';
    if (f.seq == _lastFrameSeq && key == _lastFrameKey) return _vehiclePoints;
    _lastFrameSeq = f.seq;
    _lastFrameKey = key;
    // ~40 km at zoom 10, halving with every zoom level; never below 1.5 km.
    final maxMeters = cull ? (40000 / (1 << (zoom - 10).clamp(0, 6).round())).clamp(1500, 40000).toDouble() : double.infinity;
    final small = zoom < 12.5;
    return _vehiclePoints = [
      for (final v in f.vehicles.values)
        if (!cull || haversineMeters(center, v.position) <= maxMeters)
          MapPoint(
            id: v.id,
            position: v.position,
            color: componentColor(v.component),
            radius: small ? 5 : 9,
            strokeColor: Colors.white,
            strokeWidth: small ? 1 : 2,
            label: small ? '' : (v.routeShortName ?? ''),
          ),
    ];
  }

  Future<void> _goToMyLocation() async {
    setState(() => _locating = true);
    try {
      final p = await currentPosition();
      if (mounted) setState(() => _showMyLocation = true);
      await _mapKey.currentState?.animateTo(p, zoom: 15.5);
    } on LocationDenied {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).locationDenied)));
      }
    } catch (_) {
      // Timeout or platform error: silently ignore, the map stays where it is.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _onLongPress(LatLng p) async {
    final l10n = AppLocalizations.of(context);
    final api = ref.read(apiClientProvider);
    Place place;
    try {
      place = await api.reverse(widget.cityId, p);
    } catch (_) {
      place = Place(name: p.toString(), position: p);
    }
    if (!mounted) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(place.name),
              subtitle: Text(p.toString()),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.trip_origin),
              title: Text(l10n.setAsOrigin),
              onTap: () => Navigator.pop(ctx, 'from'),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(l10n.setAsDestination),
              onTap: () => Navigator.pop(ctx, 'to'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final planner = ref.read(plannerProvider.notifier);
    if (choice == 'from') {
      planner.setFrom(place);
    } else {
      planner.setTo(place);
    }
    context.go('/${widget.cityId}/plan');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cityAsync = ref.watch(cityProvider(widget.cityId));
    final settings = ref.watch(settingsProvider);
    final scheme = Theme.of(context).colorScheme;

    return cityAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: ErrorView(error: e, onRetry: () => ref.invalidate(cityProvider(widget.cityId))),
      ),
      data: (city) {
        final center = _center ?? city.center;
        final nearby = ref.watch(nearbyStopsProvider(NearbyQuery(widget.cityId, center,
            radius: _zoom >= 15 ? 500 : (_zoom >= 13.5 ? 900 : 1500))));
        final stops = nearby.asData?.value ?? const <Stop>[];
        final showLive = settings.liveVehicles && city.features.realtimeVehicles;
        final live = showLive ? ref.watch(liveVehiclesProvider(widget.cityId)) : null;
        final frame = live?.asData?.value;

        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: TransitMap(
                  key: _mapKey,
                  initialCenter: city.center,
                  initialZoom: city.defaultZoom,
                  stops: _stopsToPoints(stops),
                  vehicles: frame == null ? const [] : _frameToPoints(frame, center, _zoom),
                  myLocation: _showMyLocation,
                  attributionBottomInset: 150,
                  onLongPress: _onLongPress,
                  onStopTap: (id) => context.push('/${widget.cityId}/stops/${Uri.encodeComponent(id)}'),
                  onVehicleTap: (id) => context.push('/${widget.cityId}/vehicles/${Uri.encodeComponent(id)}'),
                  onCameraIdle: (c, z) {
                    if (_center == null || haversineMeters(_center!, c) > 150 || (z - _zoom).abs() > 0.5) {
                      setState(() {
                        _center = c;
                        _zoom = z;
                      });
                    }
                  },
                ),
              ),
              // Search bar
              Positioned(
                top: MediaQuery.paddingOf(context).top + 12,
                left: 16,
                right: 16,
                child: _SearchBar(
                  hint: l10n.searchPlaceholder,
                  cityName: city.name,
                  onTap: () => context.go('/${widget.cityId}/plan'),
                ),
              ),
              // Side buttons
              Positioned(
                right: 16,
                top: MediaQuery.paddingOf(context).top + 84,
                child: Column(
                  children: [
                    if (city.features.realtimeVehicles)
                      _RoundButton(
                        tooltip: l10n.liveVehicles,
                        active: settings.liveVehicles,
                        icon: Icons.directions_bus,
                        onTap: () => ref
                            .read(settingsProvider.notifier)
                            .setLiveVehicles(!settings.liveVehicles),
                      ),
                    const SizedBox(height: 10),
                    _RoundButton(
                      tooltip: l10n.myLocation,
                      icon: Icons.my_location,
                      loading: _locating,
                      onTap: _goToMyLocation,
                    ),
                  ],
                ),
              ),
              if (frame != null)
                Positioned(
                  left: 16,
                  top: MediaQuery.paddingOf(context).top + 84,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const LiveBadge(compact: true),
                        const SizedBox(width: 6),
                        Text(l10n.vehiclesCount(frame.count),
                            style: Theme.of(context).textTheme.labelMedium),
                      ],
                    ),
                  ),
                ),
              // Nearby stops strip
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _NearbyStrip(
                  cityId: widget.cityId,
                  stops: stops,
                  loading: nearby.isLoading && stops.isEmpty,
                  onPlan: () => context.go('/${widget.cityId}/plan'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.hint, required this.cityName, required this.onTap});
  final String hint;
  final String cityName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.search, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(hint,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(cityName,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.active = false,
    this.loading = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool active;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? scheme.primary : scheme.surface,
        elevation: 4,
        shadowColor: Colors.black26,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, color: active ? scheme.onPrimary : scheme.onSurface),
          ),
        ),
      ),
    );
  }
}

class _NearbyStrip extends StatelessWidget {
  const _NearbyStrip({
    required this.cityId,
    required this.stops,
    required this.loading,
    required this.onPlan,
  });
  final String cityId;
  final List<Stop> stops;
  final bool loading;
  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -2))],
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(l10n.nearbyStops,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                FilledButton.icon(
                  onPressed: onPlan,
                  icon: const Icon(Icons.alt_route, size: 18),
                  label: Text(l10n.planTrip),
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      visualDensity: VisualDensity.compact),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 82,
            child: loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : stops.isEmpty
                    ? Center(
                        child: Text(l10n.longPressHint,
                            style: TextStyle(color: scheme.onSurfaceVariant)))
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: stops.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, i) => _StopCard(cityId: cityId, stop: stops[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard({required this.cityId, required this.stop});
  final String cityId;
  final Stop stop;

  @override
  Widget build(BuildContext context) {
    final color = componentColor(stop.component);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/$cityId/stops/${Uri.encodeComponent(stop.id)}'),
        child: Container(
          width: 190,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                child: Icon(stop.isStation ? Icons.subway_outlined : Icons.directions_bus,
                    color: onColor(color), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(stop.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.2)),
                    if (stop.distanceMeters != null)
                      Text(formatDistance(stop.distanceMeters!),
                          style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
