import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/live/interpolation.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/utils/colors.dart';
import '../../core/utils/geo.dart';
import '../../core/utils/location.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/transit_map.dart';
import '../../l10n/generated/app_localizations.dart';
import '../favorites/save_favorite_sheet.dart';
import '../planner/planner_state.dart';
import 'widgets/alert_carousel.dart';
import 'widgets/hub_tiles.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.cityId});
  final String cityId;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  final _mapKey = GlobalKey<TransitMapState>();
  final _sheet = DraggableScrollableController();
  LatLng? _center;
  double _zoom = 12;
  bool _locating = false;

  /// The blue dot is enabled only after the user asked for it, so the system
  /// permission prompt never appears uninvited on first launch.
  bool _showMyLocation = false;

  // Memoised overlay lists so the map only re-syncs when data really changed.
  List<Stop>? _lastStops;
  List<MapPoint> _stopPoints = const [];
  List<Poi>? _lastPois;
  List<MapPoint> _poiPoints = const [];

  // Live layer: culled id set (recomputed on frame/camera change) + ticker
  // that pushes interpolated positions at ~10 Hz while buses are moving.
  final _interp = VehicleInterpolator();
  late final Ticker _ticker = createTicker(_onTick);
  VehicleFrame? _frame;
  List<Vehicle> _culled = const [];
  String _culledKey = '';
  List<MapPoint> _vehiclePoints = const [];
  DateTime _lastPush = DateTime.fromMillisecondsSinceEpoch(0);
  List<double>? _bounds;

  static const _viewportCullAbove = 1500;

  @override
  void dispose() {
    _ticker.dispose();
    _sheet.dispose();
    super.dispose();
  }

  List<MapPoint> _stopsToPoints(List<Stop> stops, City city) {
    if (identical(stops, _lastStops)) return _stopPoints;
    _lastStops = stops;
    return _stopPoints = [
      for (final s in stops)
        MapPoint(
          id: s.id,
          position: s.position,
          color: componentColor(s.component, city: city),
          radius: s.isStation ? 7 : 5,
          label: s.name,
        ),
    ];
  }

  List<MapPoint> _poisToPoints(List<Poi> pois) {
    if (identical(pois, _lastPois)) return _poiPoints;
    _lastPois = pois;
    return _poiPoints = [
      for (final p in pois)
        MapPoint(
          id: 'poi:${p.id}',
          position: p.position,
          color: poiColor(p.type),
          radius: 8,
          strokeWidth: 1.5,
          label: poiGlyph(p.type),
        ),
    ];
  }

  /// Keeps only vehicles near the camera when the fleet is large.
  void _recull(VehicleFrame f, LatLng center, double zoom) {
    final cull = f.count > _viewportCullAbove;
    final key = cull
        ? '${f.seq}|${(zoom * 2).round()}|${center.lat.toStringAsFixed(3)}|${center.lon.toStringAsFixed(3)}'
        : '${f.seq}';
    if (key == _culledKey) return;
    _culledKey = key;
    // ~40 km at zoom 10, halving with every zoom level; never below 1.5 km.
    final maxMeters = cull
        ? (40000 / (1 << (zoom - 10).clamp(0, 6).round())).clamp(1500, 40000).toDouble()
        : double.infinity;
    _culled = [
      for (final v in f.vehicles.values)
        if (!cull || haversineMeters(center, v.position) <= maxMeters) v,
    ];
    _pushPoints(DateTime.now(), force: true);
  }

  void _pushPoints(DateTime now, {bool force = false}) {
    if (!force && now.difference(_lastPush).inMilliseconds < 100) return;
    _lastPush = now;
    final city = ref.read(cityProvider(widget.cityId)).asData?.value;
    final small = _zoom < 12.5;
    final pts = <MapPoint>[
      for (final v in _culled)
        MapPoint(
          id: v.id,
          position: _interp.positionAt(v.id, now) ?? v.position,
          color: componentColor(v.component, city: city),
          radius: small ? 5 : 9,
          strokeColor: Colors.white,
          strokeWidth: small ? 1 : 2,
          label: small ? '' : (v.routeShortName ?? ''),
        ),
    ];
    if (mounted) setState(() => _vehiclePoints = pts);
  }

  void _onTick(Duration _) {
    final now = DateTime.now();
    if (!_interp.isAnimating(now)) {
      _ticker.stop();
      _pushPoints(now, force: true);
      return;
    }
    _pushPoints(now);
  }

  void _onFrame(VehicleFrame f, LatLng center, double zoom) {
    if (!identical(f, _frame)) {
      _frame = f;
      _interp.ingest(f, DateTime.now());
      if (!_ticker.isActive) _ticker.start();
    }
    _recull(f, center, zoom);
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
            ListTile(
              leading: const Icon(Icons.star_outline),
              title: Text(l10n.saveFavorite),
              onTap: () => Navigator.pop(ctx, 'fav'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'fav') {
      await showSaveFavoriteSheet(context, ref, widget.cityId, place);
      return;
    }
    final planner = ref.read(plannerProvider.notifier);
    if (choice == 'from') {
      planner.setFrom(place);
    } else {
      planner.setTo(place);
    }
    context.go('/${widget.cityId}/plan');
  }

  void _onTile(HubTile t, City city) {
    final c = widget.cityId;
    switch (t) {
      case HubTile.plan:
        context.go('/$c/plan');
      case HubTile.locate:
        context.push('/$c/locate');
      case HubTile.nearby:
        _sheet.animateTo(0.9, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
      case HubTile.routes:
        context.push('/$c/routes');
      case HubTile.live:
        ref.read(settingsProvider.notifier).setLiveVehicles(true);
        _sheet.animateTo(0.18, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
      case HubTile.alerts:
        context.go('/$c/alerts');
      case HubTile.favorites:
        context.go('/$c/favorites');
    }
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
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
        final liveAllowed = city.features.realtimeVehicles && city.config.isEnabled('liveVehicles');
        final showLive = settings.liveVehicles && liveAllowed;
        final live = showLive ? ref.watch(liveVehiclesProvider(widget.cityId)) : null;
        final frame = live?.asData?.value;
        if (frame != null) {
          _onFrame(frame, center, _zoom);
        } else if (_frame != null) {
          _frame = null;
          _culled = const [];
          _culledKey = '';
          _interp.clear();
          _vehiclePoints = const [];
        }
        final poisAllowed = city.config.isEnabled('pois');
        final showPois = settings.poiLayer && poisAllowed && _zoom >= 12.5 && _bounds != null;
        final pois = showPois
            ? (ref.watch(poisProvider(BboxQuery(widget.cityId, _bounds!))).asData?.value ?? const <Poi>[])
            : const <Poi>[];

        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: TransitMap(
                  key: _mapKey,
                  initialCenter: city.center,
                  initialZoom: city.defaultZoom,
                  stops: _stopsToPoints(stops, city),
                  vehicles: _vehiclePoints,
                  pois: _poisToPoints(pois),
                  myLocation: _showMyLocation,
                  attributionBottomInset: 150,
                  onLongPress: _onLongPress,
                  onStopTap: (id) => context.push('/${widget.cityId}/stops/${Uri.encodeComponent(id)}'),
                  onVehicleTap: (id) => context.push('/${widget.cityId}/vehicles/${Uri.encodeComponent(id)}'),
                  onPoiTap: (id) {
                    final p = pois.where((x) => 'poi:${x.id}' == id).firstOrNull;
                    if (p == null) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('${poiLabel(p.type, l10n)}${p.name == null ? '' : ' · ${p.name}'}')));
                  },
                  onCameraIdle: (c, z) async {
                    final b = await _mapKey.currentState?.visibleBounds();
                    if (!mounted) return;
                    if (_center == null || haversineMeters(_center!, c) > 150 || (z - _zoom).abs() > 0.5 || b != null) {
                      setState(() {
                        _center = c;
                        _zoom = z;
                        _bounds = b;
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
                    if (liveAllowed)
                      _RoundButton(
                        tooltip: l10n.liveVehicles,
                        active: settings.liveVehicles,
                        icon: Icons.directions_bus,
                        onTap: () => ref
                            .read(settingsProvider.notifier)
                            .setLiveVehicles(!settings.liveVehicles),
                      ),
                    if (poisAllowed) ...[
                      const SizedBox(height: 10),
                      _RoundButton(
                        tooltip: l10n.poiLayer,
                        active: settings.poiLayer,
                        icon: Icons.local_convenience_store_outlined,
                        onTap: () => ref.read(settingsProvider.notifier).setPoiLayer(!settings.poiLayer),
                      ),
                    ],
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
                        FreshnessLabel(cityId: widget.cityId, realtime: true),
                        const SizedBox(width: 6),
                        Text(l10n.vehiclesCount(frame.count),
                            style: Theme.of(context).textTheme.labelMedium),
                      ],
                    ),
                  ),
                ),
              // Hub sheet
              DraggableScrollableSheet(
                controller: _sheet,
                initialChildSize: 0.42,
                minChildSize: 0.18,
                maxChildSize: 0.9,
                snap: true,
                snapSizes: const [0.18, 0.42, 0.9],
                builder: (context, controller) => _HubSheet(
                  cityId: widget.cityId,
                  city: city,
                  controller: controller,
                  stops: stops,
                  loading: nearby.isLoading && stops.isEmpty,
                  onTile: (t) => _onTile(t, city),
                  onService: (s) => _openExternal(s.url),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HubSheet extends ConsumerWidget {
  const _HubSheet({
    required this.cityId,
    required this.city,
    required this.controller,
    required this.stops,
    required this.loading,
    required this.onTile,
    required this.onService,
  });
  final String cityId;
  final City city;
  final ScrollController controller;
  final List<Stop> stops;
  final bool loading;
  final void Function(HubTile) onTile;
  final void Function(CityService) onService;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tiles = [
      HubTile.plan,
      if (city.config.isEnabled('board')) HubTile.locate,
      HubTile.nearby,
      HubTile.routes,
      if (city.features.realtimeVehicles && city.config.isEnabled('liveVehicles')) HubTile.live,
      if (city.features.alerts) HubTile.alerts,
      HubTile.favorites,
    ];
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -2))],
      ),
      child: ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),
          Text(l10n.hubTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4)),
          const SizedBox(height: 12),
          HubTiles(tiles: tiles, onTap: onTile),
          if (city.features.alerts) AlertCarousel(cityId: cityId),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(l10n.nearbyCardTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
              TextButton.icon(
                onPressed: () => context.push('/$cityId/locate'),
                icon: const Icon(Icons.search, size: 16),
                label: Text(l10n.searchStopHint),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (loading)
            const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          else if (stops.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(l10n.longPressHint, style: TextStyle(color: scheme.onSurfaceVariant)),
            )
          else
            for (final s in stops.take(6)) _NearbyTile(cityId: cityId, stop: s),
          if (city.services.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(l10n.services,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in city.services)
                  ActionChip(
                    avatar: Icon(iconByName(s.icon, fallback: Icons.open_in_new), size: 16),
                    label: Text(s.label),
                    onPressed: () => onService(s),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _NearbyTile extends ConsumerWidget {
  const _NearbyTile({required this.cityId, required this.stop});
  final String cityId;
  final Stop stop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ComponentBadge(stop.component, isStation: stop.isStation),
      title: Text(stop.name, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        [
          stop.isStation ? l10n.station : l10n.stop,
          if (stop.distanceMeters != null) formatDistance(stop.distanceMeters!),
        ].join(' · '),
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
      trailing: IconButton(
        tooltip: l10n.locateTitle,
        icon: const Icon(Icons.directions_bus_outlined),
        onPressed: () => context.push('/$cityId/locate?stop=${Uri.encodeComponent(stop.id)}'),
      ),
      onTap: () => context.push('/$cityId/stops/${Uri.encodeComponent(stop.id)}'),
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
