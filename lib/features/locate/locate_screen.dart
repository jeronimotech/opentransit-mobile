import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/utils/colors.dart';
import '../../core/utils/eta.dart';
import '../../core/utils/format.dart';
import '../../core/utils/geo.dart';
import '../../core/utils/location.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/transit_map.dart';
import '../../l10n/generated/app_localizations.dart';

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

// ───────────────────────── steps 2 + 3: route, next buses ─────────────────────────

class _RouteAndBuses extends ConsumerWidget {
  const _RouteAndBuses({required this.cityId, required this.stopId, required this.routeId, required this.onRoute});
  final String cityId;
  final String stopId;
  final String? routeId;
  final void Function(String) onRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final key = CityKey(cityId, stopId);
    final detail = ref.watch(stopDetailProvider(key));
    final scheme = Theme.of(context).colorScheme;
    return detail.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(stopDetailProvider(key))),
      data: (d) {
        // The feed models some directions as separate routes with the same
        // short name: group by short name for the chips.
        final seen = <String>{};
        final routes = [for (final r in d.routes) if (seen.add(r.shortName)) r];
        final selected = routes.where((r) => r.id == routeId).firstOrNull;
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            ListTile(
              leading: ComponentBadge(d.stop.component, isStation: d.stop.isStation),
              title: Text(d.stop.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(d.stop.isStation ? l10n.station : l10n.stop),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/$cityId/stops/${Uri.encodeComponent(stopId)}'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                        onTap: () => onRoute(r.id),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: r.id == routeId ? scheme.primary : Colors.transparent, width: 2),
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
              _NextBuses(cityId: cityId, stop: d.stop, route: selected),
          ],
        );
      },
    );
  }
}

class _NextBuses extends ConsumerWidget {
  const _NextBuses({required this.cityId, required this.stop, required this.route});
  final String cityId;
  final Stop stop;
  final RouteRef route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final key = StopRouteKey(cityId, stop.id, route.id);
    final next = ref.watch(nextBusesProvider(key));
    final city = ref.watch(currentCityProvider);
    final live = ref.watch(liveVehiclesProvider(cityId)).asData?.value;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final color = colorFromHex(route.color, fallback: componentColor(route.component, city: city));

    return next.when(
      loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(nextBusesProvider(key))),
      data: (r) {
        // ETA per vehicle id from the response; other buses on the route get "far".
        final eta = {for (final n in r.next) if (n.vehicle != null) n.vehicle!.id: n.minutes};
        final onRoute = live == null
            ? [for (final n in r.next) if (n.vehicle != null) n.vehicle!]
            : [for (final v in live.vehicles.values) if (v.routeId == route.id || v.routeShortName == route.shortName) v];
        final vehicles = [
          for (final v in onRoute)
            MapPoint(
              id: v.id,
              position: live?.vehicles[v.id]?.position ?? v.position,
              color: etaColor(etaBucket(eta[v.id])),
              radius: etaRadius(etaBucket(eta[v.id])),
              strokeWidth: 2,
              label: eta[v.id] == null ? '' : '${eta[v.id]}',
            ),
        ];
        final fit = [stop.position, ...onRoute.take(6).map((v) => v.position)];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(l10n.locateNext, trailing: FreshnessLabel(cityId: cityId, freshness: r.freshness)),
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
            SizedBox(
              height: 240,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: TransitMap(
                    initialCenter: stop.position,
                    initialZoom: 13,
                    vehicles: vehicles,
                    markers: [MapPoint(id: stop.id, position: stop.position, color: color, radius: 9, strokeWidth: 3)],
                    fitTo: fit,
                    fitPadding: const EdgeInsets.all(36),
                    onVehicleTap: (id) => context.push('/$cityId/vehicles/${Uri.encodeComponent(id)}'),
                  ),
                ),
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
