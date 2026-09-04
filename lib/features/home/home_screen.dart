import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/live/interpolation.dart';
import '../../core/live/marker_style.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/storage/favorites.dart';
import '../../core/utils/colors.dart';
import '../../core/utils/geo.dart';
import '../../core/utils/location.dart';
import '../../core/utils/polyline.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/transit_map.dart';
import '../../l10n/generated/app_localizations.dart';
import '../favorites/save_favorite_sheet.dart';
import '../planner/planner_state.dart';
import 'widgets/action_chips.dart';
import 'widgets/alert_carousel.dart';
import 'widgets/layers_button.dart';
import 'widgets/nearby_strip.dart';

/// Map-first home (UX audit §A): full-bleed map, a floating search pill, one
/// layers button plus locate, and a bottom sheet that peeks at 24 % with the
/// three actions and the "Cerca de ti" strip. Shortcuts, recents and alerts
/// only appear once the sheet is dragged up.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.cityId, this.focus, this.focusZoom});
  final String cityId;

  /// Optional camera target from the route query (`?lat=&lon=&zoom=`), used by
  /// "Ver en mapa" links and deep links.
  final LatLng? focus;
  final double? focusZoom;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

/// Sheet snap points (§F).
const double kSheetPeek = 0.24;
const double kSheetHalf = 0.55;
const double kSheetFull = 0.92;

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  final _mapKey = GlobalKey<TransitMapState>();
  final _sheet = DraggableScrollableController();
  LatLng? _center;
  double _zoom = 12;
  bool _locating = false;
  bool _expanded = false;

  /// The blue dot is enabled only after the user asked for it, so the system
  /// permission prompt never appears uninvited on first launch.
  bool _showMyLocation = false;

  // Memoised overlay lists so the map only re-syncs when data really changed.
  List<Stop>? _lastStops;
  List<MapPoint> _stopPoints = const [];
  List<Poi>? _lastPois;
  List<MapPoint> _poiPoints = const [];
  List<NetworkShape>? _lastShapes;
  List<MapLine> _networkLines = const [];

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
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _sheet.addListener(_onSheetMoved);
    if (widget.focus != null) _zoom = widget.focusZoom ?? 16;
  }

  @override
  void didUpdateWidget(HomeScreen old) {
    super.didUpdateWidget(old);
    final f = widget.focus;
    if (f != null && (f != old.focus || widget.focusZoom != old.focusZoom)) {
      _mapKey.currentState?.animateTo(f, zoom: widget.focusZoom ?? 16);
    }
  }

  void _onSheetMoved() {
    if (!_sheet.isAttached) return;
    final expanded = _sheet.size > (kSheetPeek + kSheetHalf) / 2;
    if (expanded != _expanded) setState(() => _expanded = expanded);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _sheet.removeListener(_onSheetMoved);
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

  /// Network layer: trunk/cable/rail shapes from zoom 12, the (much denser)
  /// zonal/feeder/dual shapes only from zoom 14. Neon feed colours fall back
  /// to the component colour, then everything is desaturated and translucent
  /// so the base map stays readable (§B/§E).
  String _shapesKey = '';
  List<MapLine> _shapesToLines(List<NetworkShape> shapes, City city, double zoom) {
    final detail = zoom >= 14;
    final key = '${identityHashCode(shapes)}|$detail';
    if (identical(shapes, _lastShapes) && key == _shapesKey) return _networkLines;
    _lastShapes = shapes;
    _shapesKey = key;
    const backbone = {Component.trunk, Component.cable, Component.rail};
    return _networkLines = [
      for (final s in shapes)
        if (detail || backbone.contains(s.component))
          MapLine(
            id: 'net:${s.id}',
            points: decodeGeometry(s.geometry),
            color: networkLineColor(s.color, componentColor(s.component, city: city),
                backbone: backbone.contains(s.component)),
            width: backbone.contains(s.component) ? 2.5 : 1,
          ),
    ];
  }

  /// Keeps only vehicles inside the visible bounds (plus a margin).
  void _recull(VehicleFrame f, LatLng center, double zoom) {
    final key = '${f.seq}|${(zoom * 2).round()}|${center.lat.toStringAsFixed(3)}|${center.lon.toStringAsFixed(3)}';
    if (key == _culledKey) return;
    _culledKey = key;
    final b = _bounds;
    if (b == null) {
      _culled = f.vehicles.values.toList(growable: false);
    } else {
      final dx = (b[2] - b[0]) * 0.25;
      final dy = (b[3] - b[1]) * 0.25;
      _culled = [
        for (final v in f.vehicles.values)
          if (v.position.lon >= b[0] - dx && v.position.lon <= b[2] + dx &&
              v.position.lat >= b[1] - dy && v.position.lat <= b[3] + dy) v,
      ];
    }
    _pushPoints(DateTime.now(), force: true);
  }

  void _pushPoints(DateTime now, {bool force = false}) {
    if (!force && now.difference(_lastPush).inMilliseconds < 100) return;
    _lastPush = now;
    final city = ref.read(cityProvider(widget.cityId)).asData?.value;
    final style = vehicleMarkerStyle(_zoom);
    if (!style.visible) {
      if (_vehiclePoints.isNotEmpty) _safeSetState(() => _vehiclePoints = const []);
      return;
    }
    final pts = <MapPoint>[
      for (final v in _culled)
        MapPoint(
          id: v.id,
          position: _reduceMotion ? v.position : (_interp.positionAt(v.id, now) ?? v.position),
          color: mapVehicleColor(componentColor(v.component, city: city)),
          radius: style.radius,
          opacity: style.opacity,
          strokeColor: Colors.white,
          strokeWidth: style.strokeWidth,
          label: style.showLabel ? (v.routeShortName ?? '') : '',
          bearing: style.showBearing ? v.bearing : null,
        ),
    ];
    _safeSetState(() => _vehiclePoints = pts);
  }

  /// setState that tolerates being reached from inside build (the live frame
  /// is folded while building): defers to the end of the frame in that case.
  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      fn();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(fn);
    }
  }

  void _onTick(Duration _) {
    final now = DateTime.now();
    if (_reduceMotion || !_interp.isAnimating(now)) {
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
      if (!_ticker.isActive && !_reduceMotion) _ticker.start();
    }
    _recull(f, center, zoom);
  }

  void _dropLive() {
    if (_frame == null) return;
    _frame = null;
    _culled = const [];
    _culledKey = '';
    _interp.clear();
    _vehiclePoints = const [];
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

  void _onAction(HomeAction a) {
    final c = widget.cityId;
    switch (a) {
      case HomeAction.plan:
        context.go('/$c/plan');
      case HomeAction.locate:
        context.push('/$c/locate');
      case HomeAction.routes:
        context.push('/$c/routes');
    }
  }

  Future<void> _onNearbyTap(Stop s) async {
    await _mapKey.currentState?.animateTo(s.position, zoom: 16);
    if (!mounted) return;
    context.push('/${widget.cityId}/stops/${Uri.encodeComponent(s.id)}');
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
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    final topInset = MediaQuery.paddingOf(context).top;

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
        final style = vehicleMarkerStyle(_zoom);
        // Subscribe to the stream only while buses can actually be drawn.
        final showLive = settings.liveVehicles && liveAllowed && style.visible;
        final live = showLive ? ref.watch(liveVehiclesProvider(widget.cityId)) : null;
        final frame = live?.asData?.value;
        if (frame != null) {
          _onFrame(frame, center, _zoom);
        } else {
          _dropLive();
        }
        final poisAllowed = city.config.isEnabled('pois');
        final showPois = settings.poiLayer && poisAllowed && _zoom >= 12.5 && _bounds != null;
        final pois = showPois
            ? (ref.watch(poisProvider(BboxQuery(widget.cityId, _bounds!))).asData?.value ?? const <Poi>[])
            : const <Poi>[];
        final showNetwork = settings.networkLayer && _zoom >= 12;
        final shapes = showNetwork
            ? (ref.watch(networkProvider(widget.cityId)).asData?.value ?? const <NetworkShape>[])
            : const <NetworkShape>[];
        final layers = MapLayers(live: settings.liveVehicles, pois: settings.poiLayer, network: settings.networkLayer);
        final liveHint = settings.liveVehicles && liveAllowed && !style.visible;

        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: TransitMap(
                  key: _mapKey,
                  initialCenter: widget.focus ?? city.center,
                  initialZoom: widget.focus == null ? city.defaultZoom : (widget.focusZoom ?? 16),
                  lines: _shapesToLines(shapes, city, _zoom),
                  stops: _stopsToPoints(stops, city),
                  vehicles: _vehiclePoints,
                  pois: _poisToPoints(pois),
                  myLocation: _showMyLocation,
                  attributionBottomInset: MediaQuery.sizeOf(context).height * kSheetPeek + 4,
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
                    if (_center == null || haversineMeters(_center!, c) > 150 || (z - _zoom).abs() > 0.3 || b != null) {
                      setState(() {
                        _center = c;
                        _zoom = z;
                        _bounds = b;
                      });
                    }
                  },
                ),
              ),
              // 1. Search pill
              Positioned(
                top: topInset + 10,
                left: 16,
                right: 16,
                child: _SearchBar(
                  hint: l10n.searchPlaceholder,
                  cityName: city.name,
                  onTap: () => context.go('/${widget.cityId}/plan'),
                ),
              ),
              // Live status / zoom hint (not interactive)
              if (frame != null || liveHint)
                Positioned(
                  left: 16,
                  top: topInset + 74,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                    ),
                    child: frame != null
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FreshnessLabel(cityId: widget.cityId, realtime: true),
                              const SizedBox(width: 6),
                              Text(l10n.vehiclesCount(_culled.length),
                                  style: Theme.of(context).textTheme.labelMedium),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.zoom_in_rounded, size: 14, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(l10n.zoomInForBuses,
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                            ],
                          ),
                  ),
                ),
              // 2 + 3. Layers and locate, above the sheet's peek edge.
              Positioned(
                right: 16,
                bottom: MediaQuery.sizeOf(context).height * kSheetPeek + 16,
                child: Column(
                  children: [
                    LayersButton(
                      layers: layers,
                      liveAvailable: liveAllowed,
                      poisAvailable: poisAllowed,
                      onChanged: (next) {
                        final n = ref.read(settingsProvider.notifier);
                        if (next.live != settings.liveVehicles) n.setLiveVehicles(next.live);
                        if (next.pois != settings.poiLayer) n.setPoiLayer(next.pois);
                        if (next.network != settings.networkLayer) n.setNetworkLayer(next.network);
                      },
                    ),
                    const SizedBox(height: 10),
                    _RoundButton(
                      key: const ValueKey('locate-me'),
                      tooltip: l10n.myLocation,
                      icon: Icons.my_location,
                      loading: _locating,
                      onTap: _goToMyLocation,
                    ),
                  ],
                ),
              ),
              // 4. Bottom sheet
              DraggableScrollableSheet(
                controller: _sheet,
                initialChildSize: kSheetPeek,
                minChildSize: kSheetPeek,
                maxChildSize: kSheetFull,
                snap: true,
                snapSizes: const [kSheetPeek, kSheetHalf, kSheetFull],
                builder: (context, controller) => _HomeSheet(
                  cityId: widget.cityId,
                  city: city,
                  controller: controller,
                  stops: stops,
                  loading: nearby.isLoading && stops.isEmpty,
                  expanded: _expanded,
                  onAction: _onAction,
                  onNearby: _onNearbyTap,
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

class _HomeSheet extends ConsumerWidget {
  const _HomeSheet({
    required this.cityId,
    required this.city,
    required this.controller,
    required this.stops,
    required this.loading,
    required this.expanded,
    required this.onAction,
    required this.onNearby,
    required this.onService,
  });
  final String cityId;
  final City city;
  final ScrollController controller;
  final List<Stop> stops;
  final bool loading;
  final bool expanded;
  final void Function(HomeAction) onAction;
  final void Function(Stop) onNearby;
  final void Function(CityService) onService;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final actions = [
      HomeAction.plan,
      if (city.config.isEnabled('board')) HomeAction.locate,
      HomeAction.routes,
    ];
    final favs = ref.watch(favoritesProvider.notifier);
    ref.watch(favoritesProvider);
    final home = favs.ofKind(cityId, FavoriteKind.home);
    final work = favs.ofKind(cityId, FavoriteKind.work);
    final recents = ref.watch(recentTripsProvider).where((t) => t.cityId == cityId).take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -2))],
      ),
      child: ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
        children: [
          Center(
            child: Semantics(
              label: l10n.moreOptions,
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Peek row 1: the three actions.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: HomeActionChips(actions: actions, onTap: onAction),
          ),
          const SizedBox(height: 10),
          // Peek row 2: "Cerca de ti".
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(l10n.nearYouTitle,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
          ),
          NearbyStrip(cityId: cityId, stops: stops, loading: loading, onTap: onNearby),
          // Only once the sheet is dragged up.
          if (expanded) ...[
            const SizedBox(height: 14),
            if (home != null || work != null || recents.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (home != null)
                      ActionChip(
                        key: const ValueKey('home-chip-home'),
                        avatar: const Icon(Icons.home_rounded, size: 16),
                        label: Text(l10n.favHome),
                        onPressed: () {
                          ref.read(plannerProvider.notifier).setTo(home.toPlace());
                          context.go('/$cityId/plan');
                        },
                      ),
                    if (work != null)
                      ActionChip(
                        key: const ValueKey('home-chip-work'),
                        avatar: const Icon(Icons.work_rounded, size: 16),
                        label: Text(l10n.favWork),
                        onPressed: () {
                          ref.read(plannerProvider.notifier).setTo(work.toPlace());
                          context.go('/$cityId/plan');
                        },
                      ),
                    for (final t in recents)
                      ActionChip(
                        avatar: const Icon(Icons.history, size: 16),
                        label: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text('${t.from.name} → ${t.to.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        onPressed: () {
                          final planner = ref.read(plannerProvider.notifier);
                          planner.setFrom(t.from);
                          planner.setTo(t.to);
                          context.go('/$cityId/plan');
                        },
                      ),
                  ],
                ),
              ),
            if (city.features.alerts)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AlertCarousel(cityId: cityId),
              ),
            if (city.services.isNotEmpty) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(l10n.services,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
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
              ),
            ],
          ] else
            // Keep the sheet scrollable past the peek so a drag reveals the rest.
            const SizedBox(height: 240),
        ],
      ),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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
              ExcludeSemantics(
                child: Container(
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
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.loading = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surface,
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
                : Icon(icon, color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}
