import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/analytics/analytics_event.dart';
import '../../core/analytics/track_view.dart';
import '../../core/storage/favorites.dart';
import '../../core/utils/colors.dart';
import '../../core/utils/links.dart';
import '../../core/utils/polyline.dart';
import '../../core/utils/line_page.dart';
import '../../core/utils/notifications.dart';
import '../../core/utils/route_alerts.dart';
import '../../core/theme/semantic_colors.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/transit_map.dart';
import '../../l10n/generated/app_localizations.dart';

class RouteDetailScreen extends ConsumerStatefulWidget {
  const RouteDetailScreen({super.key, required this.cityId, required this.routeId});
  final String cityId;
  final String routeId;

  @override
  ConsumerState<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends ConsumerState<RouteDetailScreen> {
  int _dir = 0;
  RoutePattern? _builtFor;
  List<MapLine> _lines = const [];
  List<MapPoint> _stops = const [];
  List<LatLng> _fit = const [];

  void _build(RoutePattern p, Color color) {
    if (identical(_builtFor, p)) return;
    _builtFor = p;
    final pts = decodeGeometry(p.geometry);
    _lines = [MapLine(id: p.id, points: pts, color: color, width: 6)];
    _stops = [
      for (final s in p.stops)
        MapPoint(id: s.id, position: s.position, color: Colors.white, strokeColor: color, strokeWidth: 3, radius: 5, label: s.name),
    ];
    _fit = pts.isEmpty ? p.stops.map((s) => s.position).toList() : pts;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final key = CityKey(widget.cityId, widget.routeId);
    final detail = ref.watch(routeDetailProvider(key));
    final city = ref.watch(cityProvider(widget.cityId)).asData?.value;
    final live = ref.watch(liveVehiclesProvider(widget.cityId)).asData?.value;
    final scheme = Theme.of(context).colorScheme;

    return detail.when(
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: ErrorView(error: e, onRetry: () => ref.invalidate(routeDetailProvider(key)))),
      data: (d) {
        final r = d.route;
        final color = colorFromHex(r.color, fallback: componentColor(r.component, city: city));
        final fav = Favorite.route(widget.cityId, r);
        final isFav = ref.watch(favoritesProvider).any((f) => f.key == fav.key);
        final patterns = d.patterns;
        final dir = patterns.isEmpty ? null : patterns[_dir.clamp(0, patterns.length - 1)];
        final trackView = TrackView(type: Ev.routeView, id: r.id, props: {'routeId': r.id, 'component': r.component?.name});
        if (dir != null) _build(dir, color);
        final onRoute = live == null
            ? const <Vehicle>[]
            : [for (final v in live.vehicles.values) if (v.routeId == r.id) v];
        final vehicles = [
          for (final v in onRoute)
            MapPoint(id: v.id, position: v.position, color: color, radius: 9, strokeWidth: 2, label: v.routeShortName ?? ''),
        ];
        // Which stops of the shown direction currently have a bus on them.
        final nearestStopIndexes = dir == null
            ? const <int>{}
            : nearestStopIndexesFor(onRoute, dir.stops);

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                RouteChip(r),
                const SizedBox(width: 10),
                Expanded(child: Text(r.longName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium)),
              ],
            ),
            actions: [
              IconButton(
                tooltip: l10n.share,
                icon: const Icon(Icons.share_outlined),
                onPressed: () => SharePlus.instance.share(ShareParams(uri: CanonicalLinks.route(widget.cityId, r.id))),
              ),
              _RouteAlertsButton(cityId: widget.cityId, routeId: r.id, shortName: r.shortName),
              IconButton(
                tooltip: isFav ? l10n.removeFavorite : l10n.addFavorite,
                icon: Icon(isFav ? Icons.star : Icons.star_border, color: isFav ? Colors.amber.shade700 : null),
                onPressed: () => ref.read(favoritesProvider.notifier).toggle(fav),
              ),
            ],
          ),
          body: Column(
            children: [
              trackView,
              Expanded(
                flex: 5,
                child: TransitMap(
                  initialCenter: city?.center ?? (dir?.stops.firstOrNull?.position ?? const LatLng(0, 0)),
                  initialZoom: 11,
                  lines: _lines,
                  stops: _stops,
                  vehicles: vehicles,
                  fitTo: _fit,
                  fitPadding: const EdgeInsets.all(48),
                  onStopTap: (id) => context.push('/${widget.cityId}/stops/${Uri.encodeComponent(id)}'),
                  onVehicleTap: (id) => context.push('/${widget.cityId}/vehicles/${Uri.encodeComponent(id)}'),
                ),
              ),
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (patterns.length > 1)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: SegmentedButton<int>(
                          showSelectedIcon: false,
                          segments: [
                            for (var i = 0; i < patterns.length; i++)
                              ButtonSegment(value: i, label: Text(patterns[i].headsign ?? '${l10n.direction} ${i + 1}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                          selected: {_dir.clamp(0, patterns.length - 1)},
                          onSelectionChanged: (v) => setState(() => _dir = v.first),
                        ),
                      ),
                    if (r.serviceWindow != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: Row(
                          children: [
                            Icon(Icons.schedule, size: 16, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Text('${l10n.serviceHours}: ${r.serviceWindow!.start ?? '—'} – ${r.serviceWindow!.end ?? '—'}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                            const SizedBox(width: 10),
                            Flexible(child: ServiceHint(r.serviceWindow, dense: true)),
                          ],
                        ),
                      ),
                    if (d.alerts.isNotEmpty)
                      for (final a in d.alerts)
                        ListTile(
                          dense: true,
                          leading: alertIcon(a.severity, size: 20),
                          title: Text(a.header, maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: () => context.go('/${widget.cityId}/alerts'),
                        ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              dir == null ? l10n.stops : l10n.stopsCount(dir.stops.length),
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                          Text(l10n.busesOnRoute(vehicles.length),
                              key: const ValueKey('route-live-count'),
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: vehicles.isEmpty ? scheme.onSurfaceVariant : context.semantic.live,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: dir == null
                          ? const SizedBox.shrink()
                          : ListView.builder(
                              itemCount: dir.stops.length,
                              itemBuilder: (context, i) {
                                final s = dir.stops[i];
                                final first = i == 0, last = i == dir.stops.length - 1;
                                // A bus is "here" when it is closer to this stop
                                // than to any other on the pattern.
                                final busHere = nearestStopIndexes.contains(i);
                                return InkWell(
                                  onTap: () => context.push('/${widget.cityId}/stops/${Uri.encodeComponent(s.id)}'),
                                  child: SizedBox(
                                    height: 48,
                                    child: Row(
                                      children: [
                                        const SizedBox(width: 24),
                                        SizedBox(
                                          width: 20,
                                          child: Column(
                                            children: [
                                              Expanded(child: Container(width: 4, color: first ? Colors.transparent : color)),
                                              busHere
                                                  ? Container(
                                                      key: ValueKey('bus-at-$i'),
                                                      width: 18, height: 18,
                                                      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                                                      child: const Icon(Icons.directions_bus_rounded, size: 11, color: Colors.white),
                                                    )
                                                  : Container(
                                                      width: 12, height: 12,
                                                      decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.surface, border: Border.all(color: color, width: 3)),
                                                    ),
                                              Expanded(child: Container(width: 4, color: last ? Colors.transparent : color)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: first || last || busHere ? FontWeight.w700 : FontWeight.w500))),
                                        TextButton(
                                          key: ValueKey('quick-go-$i'),
                                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact, minimumSize: const Size(0, 40)),
                                          onPressed: () => context.push(
                                              '/${widget.cityId}/locate?stop=${Uri.encodeComponent(s.id)}&route=${Uri.encodeComponent(r.id)}'),
                                          child: Text(l10n.quickGo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
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

/// Bell in the route app bar: arms local alerts for this route on a schedule.
/// Everything stays on the device — there is no push channel.
class _RouteAlertsButton extends ConsumerWidget {
  const _RouteAlertsButton({required this.cityId, required this.routeId, required this.shortName});
  final String cityId;
  final String routeId;
  final String shortName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final schedules = ref.watch(routeAlertSchedulesProvider);
    final current = schedules[routeId] ?? AlertSchedule.never;
    final on = current != AlertSchedule.never;

    String label(AlertSchedule s) => switch (s) {
          AlertSchedule.always => l10n.routeAlertsAlways,
          AlertSchedule.weekdays => l10n.routeAlertsWeekdays,
          AlertSchedule.workHours => l10n.routeAlertsWorkHours,
          AlertSchedule.never => l10n.routeAlertsNever,
        };

    return PopupMenuButton<AlertSchedule>(
      key: const ValueKey('route-alerts-menu'),
      tooltip: l10n.routeAlertsTitle,
      icon: Icon(on ? Icons.notifications_active : Icons.notifications_none,
          color: on ? Theme.of(context).colorScheme.primary : null),
      initialValue: current,
      onSelected: (v) async {
        await ref.read(routeAlertSchedulesProvider.notifier).set(cityId, routeId, v);
        if (v != AlertSchedule.never) await LocalNotifications.instance.requestPermission();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(v == AlertSchedule.never ? l10n.routeAlertsOff : l10n.routeAlertsOn),
          duration: const Duration(seconds: 2),
        ));
      },
      itemBuilder: (context) => [
        PopupMenuItem<AlertSchedule>(
          enabled: false,
          child: Text(l10n.routeAlertsTitle,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
        ),
        const PopupMenuDivider(),
        for (final s in AlertSchedule.values)
          CheckedPopupMenuItem<AlertSchedule>(
            key: ValueKey('route-alert-${s.name}'),
            value: s,
            checked: current == s,
            child: Text(label(s)),
          ),
      ],
    );
  }
}
