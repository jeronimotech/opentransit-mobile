import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics_event.dart';
import '../../core/live/interpolation.dart';
import '../../core/live/marker_style.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/theme/semantic_colors.dart';
import '../../core/utils/colors.dart';
import '../../core/utils/geo.dart';
import '../../core/utils/location.dart';
import '../../core/utils/near_me.dart';
import '../../core/utils/polyline.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/transit_map.dart';
import '../../l10n/generated/app_localizations.dart';

/// "Cerca de mí" (contract v1.9): a live map centred on the user answering
/// *what is moving around me right now, and should I care?*
///
/// The map follows the user until they touch it; the stream subscribes to the
/// bbox that encloses the radius circle, so bandwidth tracks the radius and not
/// the city; and everything stops when the screen is left.
class NearMeScreen extends ConsumerStatefulWidget {
  const NearMeScreen({super.key, required this.cityId});
  final String cityId;

  @override
  ConsumerState<NearMeScreen> createState() => _NearMeScreenState();
}

class _NearMeScreenState extends ConsumerState<NearMeScreen> {
  final _mapKey = GlobalKey<TransitMapState>();
  final _interp = VehicleInterpolator();

  StreamSubscription<Position>? _gps;
  Timer? _ticker;

  LatLng? _here;

  /// Centre the stream's bbox is built from. It lags [_here] on purpose: it
  /// only moves once the user has walked a quarter of the radius, so an
  /// ordinary walk does not tear the subscription down and build it again.
  LatLng? _anchor;

  int _radius = nearMeDefaultRadius;
  Set<Component> _components = {};
  bool _follow = true;
  bool _denied = false;
  bool _loadingFix = true;
  String? _selected;

  /// Set while the user's finger is on the map, so a camera move that follows
  /// a touch is read as theirs and one we started is not.
  bool _touching = false;
  DateTime _touchedAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(preferencesProvider);
    _radius = nearMeRadii.contains(prefs.nearMeRadius) ? prefs.nearMeRadius : nearMeDefaultRadius;
    _components = {
      for (final name in prefs.nearMeComponents) ?Component.parse(name),
    };
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted && _interp.isAnimating(DateTime.now())) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    // Both subscriptions are the whole battery cost of this screen; leaving
    // must end them, not just stop painting.
    _ticker?.cancel();
    _ticker = null;
    _gps?.cancel();
    _gps = null;
    super.dispose();
  }

  Future<void> _start() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied && !skipLocationPrompt) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _denied = true;
            _loadingFix = false;
          });
        }
        return;
      }
      final first = await currentPosition();
      if (!mounted) return;
      setState(() {
        _here = first;
        _anchor = first;
        _loadingFix = false;
      });
      // Frame the radius on the first fix, so the ring and the buses inside it
      // are both on screen from the start.
      await _mapKey.currentState?.animateTo(first, zoom: zoomForRadius(_radius));
      _gps = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
      ).listen(_onPosition, onError: (_) {});
    } catch (_) {
      if (mounted) {
        setState(() {
          _denied = true;
          _loadingFix = false;
        });
      }
    }
  }

  void _onPosition(Position p) {
    if (!mounted) return;
    final here = LatLng(p.latitude, p.longitude);
    final anchor = _anchor;
    // Re-anchor (and so re-subscribe) only after a real walk.
    final moved = anchor == null || haversineMeters(anchor, here) > _radius * 0.25;
    setState(() {
      _here = here;
      if (moved) _anchor = here;
    });
    if (_follow) _recentre(here);
  }

  Future<void> _recentre(LatLng p) async {
    // Programmatic move: mark it so onCameraIdle does not read it as a gesture.
    _touching = false;
    await _mapKey.currentState?.animateTo(p);
  }

  void _onCameraIdle(LatLng center, double zoom) {
    // A camera that settles shortly after a finger touched the map was moved by
    // the user; break the follow rather than fighting them for the viewport.
    final byUser = _touching || DateTime.now().difference(_touchedAt) < const Duration(milliseconds: 1200);
    if (byUser && _follow && mounted) setState(() => _follow = false);
  }

  Future<void> _setRadius(int r) async {
    setState(() {
      _radius = r;
      _anchor = _here ?? _anchor; // a new radius means a new bbox
    });
    await ref.read(preferencesProvider).setNearMeRadius(r);
    // Re-frame: a radius you cannot see is not a radius.
    final p = _here;
    if (p != null) {
      _touching = false;
      await _mapKey.currentState?.animateTo(p, zoom: zoomForRadius(r));
    }
  }

  Future<void> _toggleComponent(Component c) async {
    setState(() {
      _components = {..._components};
      if (!_components.remove(c)) _components.add(c);
    });
    ref.read(analyticsProvider).track(Ev.layerToggle, {'layer': 'nearMe.${c.name}', 'on': _components.contains(c)});
    await ref.read(preferencesProvider).setNearMeComponents([for (final c in _components) c.name]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final city = ref.watch(currentCityProvider);
    final here = _here;

    // Stream only once there is a fix: without a centre there is no bbox.
    VehicleFrame? frame;
    if (_anchor != null) {
      final q = BboxQuery(widget.cityId, bboxAround(_anchor!, _radius * 1.25));
      final async = ref.watch(nearbyLiveVehiclesProvider(q));
      frame = async.asData?.value;
      if (frame != null) _interp.ingest(frame, DateTime.now());
    }

    final now = DateTime.now();
    LatLng posOf(Vehicle v) => _interp.positionAt(v.id, now) ?? v.position;
    final nearby = here == null || frame == null
        ? const <NearbyVehicle>[]
        : nearbyVehicles(frame.vehicles.values, here,
            radiusMeters: _radius.toDouble(), components: _components, positionOf: posOf);

    // Selected bus: its route drawn faintly, so "this one" is unmistakable.
    final selectedVehicle = _selected == null ? null : frame?.vehicles[_selected];
    final selectedRouteId = selectedVehicle?.routeId;
    final selectedRoute = selectedRouteId == null
        ? null
        : ref.watch(routeDetailProvider(CityKey(widget.cityId, selectedRouteId))).asData?.value;

    final health = ref.watch(healthProvider(widget.cityId)).asData?.value;
    final stale = health?.realtime.isStale ?? false;
    final sheetPeek = MediaQuery.sizeOf(context).height * 0.34;
    // Without a fix and without a city we have nothing to centre on; a spinner
    // is honest, an arbitrary centre would not be.
    final centre = here ?? city?.center;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.nearMeTitle),
        actions: [FreshnessLabel(cityId: widget.cityId, realtime: !stale), const SizedBox(width: 12)],
      ),
      body: _denied
          ? _LocationDeniedView(onRetry: _start)
          : centre == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
              children: [
                Positioned.fill(
                  child: Listener(
                    onPointerDown: (_) {
                      _touching = true;
                      _touchedAt = DateTime.now();
                    },
                    onPointerUp: (_) {
                      _touching = false;
                      _touchedAt = DateTime.now();
                    },
                    child: TransitMap(
                      key: _mapKey,
                      initialCenter: centre,
                      initialZoom: zoomForRadius(_radius),
                      myLocation: true,
                      lines: [
                        if (here != null) _radiusRing(here, _radius, scheme.primary),
                        for (final p in selectedRoute?.patterns ?? const <RoutePattern>[])
                          MapLine(
                            id: 'near-pat-${p.id}',
                            points: decodeGeometry(p.geometry),
                            color: componentColor(selectedVehicle?.component, city: city).withValues(alpha: 0.35),
                            width: 3,
                          ),
                      ],
                      vehicles: [
                        for (final n in nearby)
                          MapPoint(
                            id: n.id,
                            position: posOf(n.vehicle),
                            color: mapVehicleColor(componentColor(n.vehicle.component, city: city),
                                selected: n.id == _selected),
                            radius: n.id == _selected ? 8 : 5.5,
                            strokeWidth: n.id == _selected ? 3 : 1.5,
                            opacity: stale ? 0.45 : 0.95,
                            bearing: n.vehicle.bearing,
                            label: n.vehicle.routeShortName,
                          ),
                      ],
                      onVehicleTap: _onVehicleTap,
                      onCameraIdle: _onCameraIdle,
                      attributionBottomInset: sheetPeek,
                    ),
                  ),
                ),
                if (!_follow)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 12,
                    child: Center(
                      child: _RecentrePill(
                        label: l10n.backToMyLocation,
                        onTap: () {
                          setState(() => _follow = true);
                          if (_here != null) _recentre(_here!);
                        },
                      ),
                    ),
                  ),
                DraggableScrollableSheet(
                  initialChildSize: 0.34,
                  minChildSize: 0.34,
                  maxChildSize: 0.9,
                  snap: true,
                  snapSizes: const [0.34, 0.9],
                  builder: (context, controller) => Container(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
                    ),
                    child: _NearbySheet(
                      controller: controller,
                      cityId: widget.cityId,
                      city: city,
                      nearby: nearby,
                      radius: _radius,
                      components: _components,
                      loading: _loadingFix || (_anchor != null && frame == null),
                      stale: stale,
                      selected: _selected,
                      onRadius: _setRadius,
                      onComponent: _toggleComponent,
                      onTap: _onRowTap,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  MapLine _radiusRing(LatLng centre, int radius, Color color) => MapLine(
        id: 'near-radius',
        points: _circle(centre, radius.toDouble()),
        color: color.withValues(alpha: 0.45),
        width: 2,
        dashed: true,
      );

  void _onVehicleTap(String id) {
    setState(() => _selected = id);
    context.push('/${widget.cityId}/vehicles/${Uri.encodeComponent(id)}');
  }

  Future<void> _onRowTap(NearbyVehicle n) async {
    setState(() => _selected = n.id);
    // Frame the user *and* the bus rather than zooming onto the bus alone:
    // "which one is it" is a question about the space between us, and a tight
    // zoom on the vehicle answers it by hiding half of it.
    final me = _here;
    final bus = n.vehicle.position;
    final target = me == null
        ? bus
        : LatLng((me.lat + bus.lat) / 2, (me.lon + bus.lon) / 2);
    final span = me == null ? _radius.toDouble() : haversineMeters(me, bus);
    _touching = false;
    await _mapKey.currentState?.animateTo(
      target,
      // A little margin so neither end sits on the screen edge.
      zoom: zoomForRadius((span * 0.75).round().clamp(120, 4000)),
    );
    if (!mounted) return;
    setState(() => _follow = false);
    if (mounted) context.push('/${widget.cityId}/vehicles/${Uri.encodeComponent(n.id)}');
  }
}

/// Polygon approximating the radius circle, for the soft ring on the map.
List<LatLng> _circle(LatLng c, double radiusMeters, {int points = 64}) {
  final out = <LatLng>[];
  for (var i = 0; i <= points; i++) {
    final bearing = i * 360 / points;
    out.add(_destination(c, radiusMeters, bearing));
  }
  return out;
}

LatLng _destination(LatLng from, double meters, double bearingDeg) {
  const metersPerDegLat = 111320.0;
  final rad = bearingDeg * math.pi / 180;
  final dLat = (meters * math.cos(rad)) / metersPerDegLat;
  final cosLat = math.cos(from.lat * math.pi / 180).abs().clamp(0.01, 1.0);
  final dLon = (meters * math.sin(rad)) / (metersPerDegLat * cosLat);
  return LatLng(from.lat + dLat, from.lon + dLon);
}

// ───────────────────────── sheet ─────────────────────────

class _NearbySheet extends StatelessWidget {
  const _NearbySheet({
    required this.controller,
    required this.cityId,
    required this.city,
    required this.nearby,
    required this.radius,
    required this.components,
    required this.loading,
    required this.stale,
    required this.selected,
    required this.onRadius,
    required this.onComponent,
    required this.onTap,
  });

  final ScrollController controller;
  final String cityId;
  final City? city;
  final List<NearbyVehicle> nearby;
  final int radius;
  final Set<Component> components;
  final bool loading;
  final bool stale;
  final String? selected;
  final void Function(int) onRadius;
  final void Function(Component) onComponent;
  final void Function(NearbyVehicle) onTap;

  /// The chips offer the city's own components: this was Bogotá's five, so in Toronto there was no
  /// way to filter by subway, streetcar or bus. `other` is dropped — it is the bucket for vehicles
  /// whose route we could not resolve, not something a rider would ask for by name.
  List<Component> get _filterable =>
      [for (final c in city?.componentIds ?? const <Component>[]) if (c != Component.other) c];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  loading ? l10n.nearMeLoading : l10n.nearMeCount(nearby.length, formatDistance(radius)),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Radius
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final r in nearMeRadii) ...[
                ChoiceChip(
                  key: ValueKey('near-radius-$r'),
                  label: Text(formatDistance(r)),
                  selected: r == radius,
                  onSelected: (_) => onRadius(r),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Component filter. Wrapped, not scrolled: a filter you cannot see is a
        // filter you will not use — the same reason the planner's modes stopped
        // scrolling. All five components stay reachable on a phone.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final c in _filterable)
                FilterChip(
                  key: ValueKey('near-comp-${c.name}'),
                  label: Text(componentLabel(c, l10n, city: city)),
                  selected: components.contains(c),
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(componentIcon(c, city: city), size: 16, color: componentColor(c, city: city)),
                  onSelected: (_) => onComponent(c),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else if (nearby.isEmpty)
          _EmptyNearby(radius: radius, onWiden: onRadius)
        else
          for (final n in nearby)
            _NearbyRow(
              key: ValueKey('near-row-${n.id}'),
              near: n,
              city: city,
              stale: stale,
              selected: n.id == selected,
              onTap: () => onTap(n),
            ),
      ],
    );
  }
}

class _NearbyRow extends StatelessWidget {
  const _NearbyRow({
    super.key,
    required this.near,
    required this.city,
    required this.stale,
    required this.selected,
    required this.onTap,
  });
  final NearbyVehicle near;
  final City? city;
  final bool stale;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final v = near.vehicle;
    final chipBg = componentColor(v.component, city: city);
    final chipFg = onColor(chipBg);
    final label = v.routeShortName ?? v.label ?? '—';
    final approach = switch (near.approach) {
      Approach.approaching => (Icons.arrow_downward_rounded, context.semantic.live, l10n.nearMeApproaching),
      Approach.away => (Icons.arrow_upward_rounded, scheme.outline, l10n.nearMeLeaving),
      Approach.unknown => null,
    };
    return ListTile(
      onTap: onTap,
      selected: selected,
      selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.35),
      leading: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(8)),
        child: Text(label,
            style: TextStyle(color: chipFg, fontWeight: FontWeight.w800, fontSize: 13)),
      ),
      title: Text(
        componentLabel(v.component, l10n, city: city),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (approach case final a?) ...[
            Icon(a.$1, size: 16, color: a.$2),
            const SizedBox(width: 2),
          ],
          Text(
            l10n.nearMeAt(formatDistance(near.distanceMeters)),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: stale ? scheme.outline : scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNearby extends StatelessWidget {
  const _EmptyNearby({required this.radius, required this.onWiden});
  final int radius;
  final void Function(int) onWiden;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final wider = widerRadius(radius);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        children: [
          Icon(Icons.no_transfer_rounded, size: 36, color: scheme.outline),
          const SizedBox(height: 10),
          Text(
            l10n.nearMeEmpty(formatDistance(radius)),
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          if (wider != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              key: const ValueKey('near-widen'),
              onPressed: () => onWiden(wider),
              icon: const Icon(Icons.zoom_out_map_rounded, size: 18),
              label: Text(l10n.nearMeWiden(formatDistance(wider))),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentrePill extends StatelessWidget {
  const _RecentrePill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 4,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        key: const ValueKey('near-recentre'),
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.my_location_rounded, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationDeniedView extends StatelessWidget {
  const _LocationDeniedView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_disabled_rounded, size: 44, color: scheme.outline),
            const SizedBox(height: 12),
            Text(l10n.nearMeNeedsLocation, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}
