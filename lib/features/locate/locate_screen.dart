import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/live/interpolation.dart';
import '../../core/live/marker_style.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/utils/colors.dart';
import '../../core/utils/eta.dart';
import '../../core/utils/format.dart';
import '../../core/utils/geo.dart';
import '../../core/utils/location.dart';
import '../../core/utils/polyline.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/transit_map.dart';
import '../../l10n/generated/app_localizations.dart';
import 'locate_status.dart';

/// "Ubica tu bus": station → route → next buses (En vivo / Por programación /
/// Estimado), with the route's buses on a map tinted by ETA bucket.
class LocateScreen extends ConsumerStatefulWidget {
  const LocateScreen({super.key, required this.cityId, this.stopId, this.routeId});
  final String cityId;
  final String? stopId;
  final String? routeId;

  @override
  ConsumerState<LocateScreen> createState() => _LocateScreenState();
}

class _LocateScreenState extends ConsumerState<LocateScreen> {
  String? _stopId;
  String? _routeId;

  @override
  void initState() {
    super.initState();
    _stopId = widget.stopId;
    _routeId = widget.routeId;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.locateTitle),
        actions: [
          if (_stopId != null)
            TextButton.icon(
              onPressed: () => setState(() {
                _stopId = null;
                _routeId = null;
              }),
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: Text(l10n.changeStop),
            ),
        ],
      ),
      body: _stopId == null
          ? _StopPicker(cityId: widget.cityId, onPick: (id) => setState(() => _stopId = id))
          : _RouteAndBuses(
              cityId: widget.cityId,
              stopId: _stopId!,
              routeId: _routeId,
              onRoute: (id) => setState(() => _routeId = id),
            ),
    );
  }
}

// ───────────────────────── step 1: stop ─────────────────────────

class _StopPicker extends ConsumerStatefulWidget {
  const _StopPicker({required this.cityId, required this.onPick});
  final String cityId;
  final void Function(String stopId) onPick;

  @override
  ConsumerState<_StopPicker> createState() => _StopPickerState();
}

class _StopPickerState extends ConsumerState<_StopPicker> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<GeocodeResult> _results = const [];
  LatLng? _here;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    try {
      final p = await currentPosition();
      if (mounted) setState(() => _here = p);
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _loading = true);
    try {
      final city = await ref.read(cityProvider(widget.cityId).future);
      final r = await ref.read(apiClientProvider).geocode(widget.cityId, q, near: _here ?? city.center, limit: 12);
      if (!mounted) return;
      setState(() {
        _results = r.where((x) => x.stopId != null).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final city = ref.watch(cityProvider(widget.cityId)).asData?.value;
    final at = _here ?? city?.center;
    final nearby = at == null
        ? null
        : ref.watch(nearbyStopsProvider(NearbyQuery(widget.cityId, at, radius: 1200)));
    final stops = nearby?.asData?.value ?? const <Stop>[];
    final q = _controller.text.trim();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(l10n.locateStep1, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            key: const ValueKey('locate-search'),
            controller: _controller,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: l10n.searchStopHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: q.isEmpty ? null : IconButton(icon: const Icon(Icons.clear), onPressed: () { _controller.clear(); _search(''); }),
            ),
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (q.isEmpty) ...[
          SectionTitle(_here == null ? l10n.nearbyStops : l10n.nearYou),
          if (nearby?.isLoading ?? false)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          for (final s in stops.take(12))
            ListTile(
              leading: ComponentBadge(s.component, isStation: s.isStation),
              title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text([
                s.isStation ? l10n.station : l10n.stop,
                if (s.distanceMeters != null) formatDistance(s.distanceMeters!),
              ].join(' · ')),
              onTap: () => widget.onPick(s.id),
            ),
        ] else
          for (final r in _results)
            ListTile(
              leading: ComponentBadge(r.component, isStation: r.type == 'station'),
              title: Text(r.name),
              subtitle: r.label == null ? null : Text(r.label!, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => widget.onPick(r.stopId!),
            ),
      ],
    );
  }
}

// ───────────────────────── steps 2 + 3: route, next buses (map-first) ─────────────────────────

/// Map-first (UX audit): the map is full-bleed under the app bar; the stop
/// header, route chips and next buses live in a draggable sheet (50 / 92 %).
/// With a route selected the map shows its pattern (the direction serving
/// this stop at full opacity, the other faint), ALL its live buses (small dots
/// with bearing, interpolated between frames), the ones heading here tinted
/// by ETA bucket and labelled with their minutes, and the stop highlighted.
class _RouteAndBuses extends ConsumerStatefulWidget {
  const _RouteAndBuses({required this.cityId, required this.stopId, required this.routeId, required this.onRoute});
  final String cityId;
  final String stopId;
  final String? routeId;
  final void Function(String) onRoute;

  @override
  ConsumerState<_RouteAndBuses> createState() => _RouteAndBusesState();
}

class _RouteAndBusesState extends ConsumerState<_RouteAndBuses> {
  final _interp = VehicleInterpolator();
  Timer? _ticker;
  VehicleFrame? _frame;
  bool _fitRoute = false;
  String? _fitKey;
  List<LatLng>? _fit;

  @override
  void initState() {
    super.initState();
    // ~10 Hz while buses are moving between frames (same as Home).
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted && _frame != null && _interp.isAnimating(DateTime.now())) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _RouteAndBuses old) {
    super.didUpdateWidget(old);
    if (old.routeId != widget.routeId || old.stopId != widget.stopId) _fitRoute = false;
  }

  /// A new list only when the fit target changes: TransitMap re-fits whenever
  /// the list identity changes, and this widget rebuilds ~10 Hz.
  List<LatLng>? _fitFor(String key, List<LatLng> Function() build) {
    if (key != _fitKey) {
      _fitKey = key;
      _fit = build();
    }
    return _fit;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final key = CityKey(widget.cityId, widget.stopId);
    final detail = ref.watch(stopDetailProvider(key));
    final scheme = Theme.of(context).colorScheme;
    final city = ref.watch(currentCityProvider);
    ref.listen<AsyncValue<VehicleFrame>>(liveVehiclesProvider(widget.cityId), (_, next) {
      final f = next.asData?.value;
      if (f != null) {
        _interp.ingest(f, DateTime.now());
        _frame = f;
      }
    });
    _frame ??= ref.watch(liveVehiclesProvider(widget.cityId)).asData?.value;
    final now = DateTime.now();
    final mapHeight = MediaQuery.sizeOf(context).height * 0.5;

    return detail.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(stopDetailProvider(key))),
      data: (d) {
        // The feed models some directions as separate routes with the same
        // short name: group by short name for the chips.
        final seen = <String>{};
        final routes = [for (final r in d.routes) if (seen.add(r.shortName)) r];
        final byId = d.routes.where((r) => r.id == widget.routeId).firstOrNull;
        final selected = byId == null ? null : (routes.where((r) => r.shortName == byId.shortName).firstOrNull ?? byId);
        final stop = d.stop.component == null ? d.stop.withComponent(dominantComponent(d.routes)) : d.stop;
        final ids = selected == null ? const <String>[] : [for (final r in d.routes) if (r.shortName == selected.shortName) r.id];
        final routeColor = selected == null
            ? componentColor(stop.component, city: city)
            : colorFromHex(selected.color, fallback: componentColor(selected.component, city: city));

        // Route geometry (both directions) and next buses, when a route is selected.
        final routeDetail = selected == null ? null : ref.watch(routeDetailProvider(CityKey(widget.cityId, selected.id))).asData?.value;
        final next = selected == null ? null : _mergedNext(ref, widget.cityId, stop.id, ids);
        final nextData = next?.asData?.value;
        final eta = {for (final n in nextData?.next ?? const <NextBus>[]) if (n.vehicle != null) n.vehicle!.id: n.minutes};

        // ── map layers ──
        final lines = <MapLine>[];
        final routePoints = <LatLng>[];
        bool serves(RoutePattern p) => p.stops.any((s) =>
            s.id == stop.id || s.parentStationId == stop.id || (stop.parentStationId != null && s.id == stop.parentStationId));
        for (final p in routeDetail?.patterns ?? const <RoutePattern>[]) {
          final pts = decodeGeometry(p.geometry);
          routePoints.addAll(pts);
          final here = serves(p);
          lines.add(MapLine(id: 'pat-${p.id}', points: pts, color: here ? routeColor : routeColor.withValues(alpha: 0.3), width: here ? 5 : 3));
        }
        final onRoute = <Vehicle>[];
        if (selected != null) {
          if (_frame != null) {
            onRoute.addAll(_frame!.vehicles.values.where((v) => ids.contains(v.routeId) || v.routeShortName == selected.shortName));
          } else {
            onRoute.addAll([for (final n in nextData?.next ?? const <NextBus>[]) if (n.vehicle != null) n.vehicle!]);
          }
        } else if (_frame != null) {
          // No route yet: the stop with its nearby live buses (any route).
          onRoute.addAll(_frame!.vehicles.values.where((v) => haversineMeters(v.position, stop.position) <= 1500));
        }
        final vehicles = <MapPoint>[
          for (final v in onRoute)
            if (eta.containsKey(v.id))
              MapPoint(
                id: v.id,
                position: _interp.positionAt(v.id, now) ?? v.position,
                color: etaColor(etaBucket(eta[v.id])),
                radius: etaRadius(etaBucket(eta[v.id])),
                strokeWidth: 2.5,
                label: '${eta[v.id]}',
                bearing: v.bearing,
              )
            else
              MapPoint(
                id: v.id,
                position: _interp.positionAt(v.id, now) ?? v.position,
                color: mapVehicleColor(selected == null ? componentColor(v.component, city: city) : routeColor),
                radius: 4.5,
                opacity: 0.9,
                strokeWidth: 1.5,
                bearing: v.bearing,
              ),
        ];
        final upstream = [for (final v in onRoute) if (eta.containsKey(v.id)) v]
          ..sort((a, b) => (eta[a.id] ?? 999).compareTo(eta[b.id] ?? 999));
        final fitKey = _fitRoute
            ? 'route|${selected?.id}|${routePoints.length}'
            : 'stop|${stop.id}|${selected?.id}|${upstream.take(4).map((v) => v.id).join(',')}|${routePoints.isEmpty ? 0 : 1}';
        final fit = _fitFor(fitKey, () {
          if (_fitRoute && routePoints.isNotEmpty) return routePoints;
          if (upstream.isNotEmpty) return [stop.position, ...upstream.take(4).map((v) => v.position)];
          if (routePoints.isNotEmpty) return routePoints;
          return [stop.position];
        });

        final status = nextData == null
            ? null
            : locateStatus(
                vehiclesOnRoute: nextData.vehiclesOnRoute,
                next: nextData.next,
                frame: _frame,
                routeIds: ids,
                shortName: selected?.shortName,
              );

        return Stack(
          children: [
            Positioned.fill(
              child: TransitMap(
                initialCenter: stop.position,
                initialZoom: selected == null ? 15 : 13,
                lines: lines,
                vehicles: vehicles,
                markers: [MapPoint(id: stop.id, position: stop.position, color: routeColor, radius: 10, strokeWidth: 3.5, label: stop.name)],
                fitTo: fit,
                fitPadding: EdgeInsets.fromLTRB(48, 90, 48, mapHeight + 24),
                onVehicleTap: (id) => context.push('/${widget.cityId}/vehicles/${Uri.encodeComponent(id)}'),
                attributionBottomInset: mapHeight,
              ),
            ),
            DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.5,
              maxChildSize: 0.92,
              snap: true,
              snapSizes: const [0.5, 0.92],
              builder: (context, controller) => Container(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16)],
                ),
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 8, bottom: 4),
                        width: 36, height: 4,
                        decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    ListTile(
                      leading: ComponentBadge(stop.component, isStation: stop.isStation),
                      title: Text(stop.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(stop.isStation ? l10n.station : l10n.stop),
                      trailing: selected == null
                          ? const Icon(Icons.chevron_right)
                          : TextButton.icon(
                              key: const ValueKey('locate-fit-route'),
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              onPressed: routePoints.isEmpty ? null : () => setState(() => _fitRoute = !_fitRoute),
                              icon: Icon(_fitRoute ? Icons.center_focus_strong : Icons.route_outlined, size: 18),
                              label: Text(l10n.viewFullRoute),
                            ),
                      onTap: () => context.push('/${widget.cityId}/stops/${Uri.encodeComponent(widget.stopId)}'),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Text(l10n.locateStep2, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    if (routes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(l10n.noRoutes, style: TextStyle(color: scheme.onSurfaceVariant)),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final r in routes)
                              InkWell(
                                key: ValueKey('locate-route-${r.shortName}'),
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => widget.onRoute(r.id),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: r.shortName == selected?.shortName ? scheme.primary : Colors.transparent, width: 2),
                                  ),
                                  child: RouteChip(r),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (selected == null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                        child: Text(l10n.selectRoute, style: TextStyle(color: scheme.onSurfaceVariant)),
                      )
                    else
                      _NextBusesList(
                        cityId: widget.cityId,
                        stop: stop,
                        ids: ids,
                        next: next!,
                        status: status,
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Merges the next buses of every route id behind one chip (both directions
/// share a short name in this feed): loading while nothing arrived, error only
/// if every id failed.
AsyncValue<NextBusesResponse> _mergedNext(WidgetRef ref, String cityId, String stopId, List<String> ids) {
  final results = [for (final id in ids) ref.watch(nextBusesProvider(StopRouteKey(cityId, stopId, id)))];
  final datas = [for (final r in results) if (r.asData != null) r.asData!.value];
  if (datas.isNotEmpty) {
    final merged = [for (final d in datas) ...d.next]..sort((a, b) => a.time.compareTo(b.time));
    final counts = [for (final d in datas) if (d.vehiclesOnRoute != null) d.vehiclesOnRoute!];
    return AsyncValue.data(NextBusesResponse(
      stop: datas.first.stop,
      route: datas.first.route,
      freshness: datas.firstWhere((d) => d.freshness.realtime, orElse: () => datas.first).freshness,
      next: merged.take(3).toList(),
      vehiclesOnRoute: counts.isEmpty ? null : counts.fold<int>(0, (a, b) => a + b),
      servesStop: datas.any((d) => d.servesStop == true) ? true : datas.first.servesStop,
    ));
  }
  if (results.every((r) => r.hasError)) {
    return AsyncValue.error(results.first.error!, results.first.stackTrace ?? StackTrace.current);
  }
  return const AsyncValue.loading();
}

class _NextBusesList extends ConsumerWidget {
  const _NextBusesList({required this.cityId, required this.stop, required this.ids, required this.next, required this.status});
  final String cityId;
  final Stop stop;
  final List<String> ids;
  final AsyncValue<NextBusesResponse> next;
  final LocateStatus? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    return next.when(
      loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => ErrorView(
          error: e,
          onRetry: () {
            for (final id in ids) {
              ref.invalidate(nextBusesProvider(StopRouteKey(cityId, stop.id, id)));
            }
          }),
      data: (r) {
        final st = status;
        final statusText = st == null
            ? null
            : switch (st.kind) {
                LocateStatusKind.noLive => l10n.locateNoLive,
                LocateStatusKind.noneComing => l10n.locateNoneComing(st.onRoute),
                LocateStatusKind.coming => l10n.locateComing(st.onRoute, st.coming),
              };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(l10n.locateNext, trailing: FreshnessLabel(cityId: cityId, freshness: r.freshness)),
            if (statusText != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(statusText, key: const ValueKey('locate-status'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.outline)),
              ),
            if (r.next.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(l10n.noBuses, style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            for (final n in r.next)
              ListTile(
                key: ValueKey('next-${n.tripId ?? n.time.toIso8601String()}'),
                leading: CircleAvatar(
                  backgroundColor: etaColor(etaBucket(n.minutes)),
                  child: Text('${n.minutes.clamp(0, 999)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
                title: Text(n.minutes <= 0 ? l10n.arrivingNow : l10n.inMinutes(n.minutes),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Row(
                  children: [
                    _SourceBadge(source: n.source),
                    const SizedBox(width: 8),
                    Text(formatClock(n.time, locale)),
                    if (n.stopsAway != null) ...[
                      const SizedBox(width: 8),
                      Text('· ${l10n.stopsAway(n.stopsAway!)}'),
                    ],
                    if (n.distanceMeters != null) ...[
                      const SizedBox(width: 8),
                      Text('· ${formatDistance(n.distanceMeters!)}'),
                    ],
                  ],
                ),
                trailing: n.vehicle == null ? null : const Icon(Icons.chevron_right),
                onTap: n.vehicle == null ? null : () => context.push('/$cityId/vehicles/${Uri.encodeComponent(n.vehicle!.id)}'),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  for (final b in [EtaBucket.imminent, EtaBucket.soon, EtaBucket.later])
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Row(children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: etaColor(b), shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text(switch (b) { EtaBucket.imminent => '≤5', EtaBucket.soon => '≤10', _ => '≤15' },
                            style: Theme.of(context).textTheme.labelSmall),
                      ]),
                    ),
                  Text('min', style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});
  final String source;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (text, color) = switch (source) {
      'live' => (l10n.sourceLive, Colors.green.shade700),
      'estimated' => (l10n.sourceEstimated, Colors.orange.shade800),
      _ => (l10n.sourceScheduled, Theme.of(context).colorScheme.outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
