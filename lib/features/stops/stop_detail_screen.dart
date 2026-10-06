import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/analytics/analytics_event.dart';
import '../../core/analytics/track_view.dart';
import '../../core/storage/favorites.dart';
import '../../core/live/marker_style.dart';
import '../../core/utils/colors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/links.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/transit_map.dart';
import '../../l10n/generated/app_localizations.dart';
import '../favorites/save_favorite_sheet.dart';
import '../planner/planner_state.dart';
import 'widgets/board_view.dart';

/// Stop / station page, map-first: the map fills the page and the board rides in a
/// draggable sheet over it, the same shape as locate, home, near_me, itinerary_detail
/// and forecast_sheet. It used to be "board first" — a 120 px map strip plus a separate
/// "Ver en mapa" modal — which made the map both too small to read and duplicated, and
/// left the list eating the screen. The approaching buses draw on that map, because
/// "3 min" from a feed that may be stale is the one claim a rider cannot check and a bus
/// two blocks away is.
/// Historic note: the header chips, then the arrival board above the fold,
/// routes collapsed, and accessibility as a muted line at the end.
class StopDetailScreen extends ConsumerWidget {
  const StopDetailScreen({super.key, required this.cityId, required this.stopId});
  final String cityId;
  final String stopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final key = CityKey(cityId, stopId);
    final detail = ref.watch(stopDetailProvider(key));
    final city = ref.watch(currentCityProvider);
    final scheme = Theme.of(context).colorScheme;

    return detail.when(
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(error: e, onRetry: () => ref.invalidate(stopDetailProvider(key))),
      ),
      data: (d) {
        // Parent stations arrive without a component: infer it from their routes.
        final stop = d.stop.component == null ? d.stop.withComponent(dominantComponent(d.routes)) : d.stop;
        final fav = Favorite.stop(cityId, stop);
        final isFav = ref.watch(favoritesProvider).any((f) => f.key == fav.key);
        final color = componentColor(stop.component, city: city);
        final place = Place(name: stop.name, position: stop.position, stopId: stop.id, component: stop.component);
        final access = stop.access;
        final boardEnabled = city?.config.isEnabled('board') ?? true;
        final trackView = TrackView(type: Ev.stopView, id: stop.id, props: {'stopId': stop.id, 'component': stop.component?.name});
        final routes = _dedupe(d.routes);
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(stop.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  _subtitle(stop, l10n, city),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: isFav ? l10n.removeFavorite : l10n.addFavorite,
                icon: Icon(isFav ? Icons.star : Icons.star_border, color: isFav ? Colors.amber.shade700 : null),
                onPressed: () => ref.read(favoritesProvider.notifier).toggle(fav),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  final planner = ref.read(plannerProvider.notifier);
                  switch (v) {
                    case 'to':
                      planner.setTo(place);
                      context.go('/$cityId/plan');
                    case 'ondemand':
                      // Taxi / ride-hailing to this stop: destination prefilled,
                      // on-demand options on; the user picks the origin.
                      planner.setTo(place);
                      planner.setOnDemand(true);
                      context.go('/$cityId/plan');
                    case 'from':
                      planner.setFrom(place);
                      context.go('/$cityId/plan');
                    case 'saveAs':
                      await showSaveFavoriteSheet(context, ref, cityId, place);
                    case 'share':
                      await SharePlus.instance.share(ShareParams(uri: CanonicalLinks.stop(cityId, stop.id)));
                    case 'pqrs':
                      final url = city?.links.pqrs;
                      if (url != null) {
                        try {
                          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                        } catch (_) {}
                      }
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'to', child: ListTile(leading: const Icon(Icons.flag_outlined), title: Text(l10n.goHere))),
                  PopupMenuItem(value: 'from', child: ListTile(leading: const Icon(Icons.trip_origin), title: Text(l10n.leaveFrom))),
                  PopupMenuItem(value: 'saveAs', child: ListTile(leading: const Icon(Icons.home_outlined), title: Text(l10n.saveAs))),
                  PopupMenuItem(value: 'share', child: ListTile(leading: const Icon(Icons.share_outlined), title: Text(l10n.share))),
                  if (city?.onDemandEnabled ?? false)
                    PopupMenuItem(value: 'ondemand', child: ListTile(leading: const Icon(Icons.local_taxi_outlined), title: Text(l10n.onDemandToHere))),
                  if (city?.links.pqrs != null)
                    PopupMenuItem(value: 'pqrs', child: ListTile(leading: const Icon(Icons.report_outlined), title: Text(l10n.reportProblem))),
                ],
              ),
            ],
          ),
          // The sheet floats over the map, so the bar must not reserve space for itself.
          extendBodyBehindAppBar: true,
          body: BoardScope(
            stopId: stopId,
            child: Stack(
              children: [
                Positioned.fill(child: _StopMap(cityId: cityId, stop: stop, color: color)),
                DraggableScrollableSheet(
                  initialChildSize: 0.42,
                  minChildSize: 0.22,
                  maxChildSize: 0.92,
                  snap: true,
                  snapSizes: const [0.22, 0.42, 0.92],
                  builder: (context, controller) => Container(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListView(
                      controller: controller,
                      padding: const EdgeInsets.only(bottom: 32),
                      children: [
                        const _SheetGrabber(),
                        trackView,
                // 1. Arrival board first (the component lives in the header subtitle).
                BoardView(
                  cityId: cityId,
                  stopId: stopId,
                  onLocate: boardEnabled ? () => context.push('/$cityId/locate?stop=${Uri.encodeComponent(stop.id)}') : null,
                ),
                // 1b. Taxi / ride-hailing to this stop (v1.4), a quiet secondary action.
                if (city?.onDemandEnabled ?? false)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: const ValueKey('stop-ondemand'),
                        style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                        onPressed: () {
                          final planner = ref.read(plannerProvider.notifier);
                          planner.setTo(Place(name: stop.name, position: stop.position, stopId: stop.id, component: stop.component));
                          planner.setOnDemand(true);
                          context.push('/$cityId/plan');
                        },
                        icon: const Icon(Icons.local_taxi_outlined, size: 18),
                        label: Text(l10n.onDemandToHere),
                      ),
                    ),
                  ),
                // 2. Routes, collapsed.
                if (routes.isNotEmpty)
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      key: const ValueKey('routes-section'),
                      title: Text(l10n.routesCount(routes.length),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final r in routes)
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => context.push('/$cityId/routes/${Uri.encodeComponent(r.id)}'),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(minHeight: 36),
                                  child: RouteChip(r),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                _StopAlerts(cityId: cityId, stopId: stopId, routeIds: d.routes.map((r) => r.id).toSet()),
                // 3. Accessibility: one muted line.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _AccessibilityLine(access: access),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Text(stop.id, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.outline)),
                ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// "Estación troncal" / "Parada zonal · A123": kind + component (+ code).
  static String _subtitle(Stop stop, AppLocalizations l10n, City? city) {
    final label = componentLabel(stop.component, l10n, city: city);
    // Lower-case plain words ("Troncal" → "troncal"), keep brands ("TransMiCable").
    final lower = RegExp(r'^[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+$').hasMatch(label) ? label.toLowerCase() : label;
    final kind = stop.isStation ? l10n.station : l10n.stop;
    return [
      '$kind $lower',
      if (stop.code != null && stop.code!.isNotEmpty) stop.code!,
    ].join(' · ');
  }

  static List<RouteRef> _dedupe(List<RouteRef> routes) {
    final seen = <String>{};
    return [for (final r in routes) if (seen.add(r.shortName)) r];
  }
}

class _AccessibilityLine extends StatelessWidget {
  const _AccessibilityLine({required this.access});
  final StopAccessibility access;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (icon, text) = switch (access.wheelchair) {
      WheelchairAccess.accessible => (Icons.accessible, l10n.accessible),
      WheelchairAccess.notAccessible => (Icons.not_accessible, l10n.accessibilityNotAccessible),
      WheelchairAccess.unknown => (Icons.help_outline, l10n.accessibilityUnknown),
    };
    final note = access.verified ? l10n.accessibilityVerified : (access.note ?? l10n.accessibilityUnverified);
    return Semantics(
      label: '${l10n.accessibility}: $text. $note',
      child: ExcludeSemantics(
        child: Row(
          children: [
            Icon(icon, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$text · $note',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopAlerts extends ConsumerWidget {
  const _StopAlerts({required this.cityId, required this.stopId, required this.routeIds});
  final String cityId;
  final String stopId;
  final Set<String> routeIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final alerts = ref.watch(alertsProvider(cityId)).asData?.value ?? const <TransitAlert>[];
    final relevant = alerts.where((a) => a.stopIds.contains(stopId) || a.routeIds.any(routeIds.contains)).toList();
    if (relevant.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(l10n.alerts),
        for (final a in relevant.take(3))
          ListTile(
            leading: alertIcon(a.severity),
            title: Text(a.header),
            subtitle: a.description == null ? null : Text(a.description!, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () => context.go('/$cityId/alerts'),
          ),
      ],
    );
  }
}

/// Kept for callers that still want a flat countdown list.
String countdownLabel(DateTime t, AppLocalizations l10n) => formatCountdown(t, l10n);


/// The grabber: without it a sheet that can be dragged does not look like one.
class _SheetGrabber extends StatelessWidget {
  const _SheetGrabber();
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

/// The stop and the buses coming to it.
///
/// Positions ride on the board rows themselves (`BoardTime.vehicle`), so this draws exactly
/// the departures the list is showing — no second request, and no chance of the map and the
/// list disagreeing about which bus is which. A departure with no live match contributes
/// nothing rather than borrowing another bus's position.
class _StopMap extends ConsumerWidget {
  const _StopMap({required this.cityId, required this.stop, required this.color});
  final String cityId;
  final Stop stop;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(boardProvider(CityKey(cityId, stop.id)));
    final vehicles = board.maybeWhen(
      data: (b) => <Vehicle>[
        for (final row in b.rows)
          for (final t in row.next)
            if (t.vehicle != null) t.vehicle!,
      ],
      orElse: () => const <Vehicle>[],
    );
    // One bus can serve two rows of the same board; drawing it twice stacks markers.
    final unique = {for (final v in vehicles) v.id: v}.values.toList(growable: false);
    final city = ref.watch(currentCityProvider);
    return TransitMap(
      initialCenter: stop.position,
      initialZoom: 15.5,
      markers: [MapPoint(id: stop.id, position: stop.position, color: color, radius: 10, strokeWidth: 3)],
      vehicles: [
        for (final v in unique)
          MapPoint(
            id: v.id,
            position: v.position,
            color: mapVehicleColor(componentColor(v.component, city: city)),
            radius: 6,
            strokeWidth: 1.5,
            bearing: v.bearing,
            label: v.routeShortName,
          ),
      ],
      // Leave room for the sheet at its resting height, so a bus is never drawn under it.
      fitPadding: const EdgeInsets.fromLTRB(40, 120, 40, 320),
    );
  }
}
