import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/storage/favorites.dart';
import '../../core/utils/colors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/links.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/transit_map.dart';
import '../../l10n/generated/app_localizations.dart';
import '../favorites/save_favorite_sheet.dart';
import '../planner/planner_state.dart';
import 'widgets/board_view.dart';

/// Stop / station page, "board first" (UX audit §D): a 120 px map strip with
/// "Ver en mapa", the header chips, then the arrival board above the fold,
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
        final routes = _dedupe(d.routes);
        return Scaffold(
          appBar: AppBar(
            title: Text(stop.name, maxLines: 1, overflow: TextOverflow.ellipsis),
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
                  if (city?.links.pqrs != null)
                    PopupMenuItem(value: 'pqrs', child: ListTile(leading: const Icon(Icons.report_outlined), title: Text(l10n.reportProblem))),
                ],
              ),
            ],
          ),
          body: BoardScope(
            stopId: stopId,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                // 120 px map strip with "Ver en mapa" (full map in a sheet).
                SizedBox(
                  height: 120,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      IgnorePointer(
                        child: TransitMap(
                          initialCenter: stop.position,
                          initialZoom: 15.5,
                          markers: [MapPoint(id: stop.id, position: stop.position, color: color, radius: 9, strokeWidth: 3)],
                        ),
                      ),
                      Positioned(
                        right: 12,
                        bottom: 10,
                        child: FilledButton.tonalIcon(
                          key: const ValueKey('view-on-map'),
                          style: FilledButton.styleFrom(minimumSize: const Size(44, 40), visualDensity: VisualDensity.compact),
                          onPressed: () => _showFullMap(context, stop, color),
                          icon: const Icon(Icons.map_outlined, size: 18),
                          label: Text(l10n.viewOnMapAction),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Chip(
                        backgroundColor: color,
                        avatar: Icon(stop.isStation ? Icons.subway_outlined : componentIcon(stop.component, city: city), size: 16, color: onColor(color)),
                        label: Text(componentLabel(stop.component, l10n, city: city), style: TextStyle(color: onColor(color), fontWeight: FontWeight.w700)),
                        visualDensity: VisualDensity.compact,
                      ),
                      if (stop.code != null) Chip(label: Text(stop.code!), visualDensity: VisualDensity.compact),
                    ],
                  ),
                ),
                // 1. Arrival board first.
                BoardView(
                  cityId: cityId,
                  stopId: stopId,
                  onLocate: boardEnabled ? () => context.push('/$cityId/locate?stop=${Uri.encodeComponent(stop.id)}') : null,
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
        );
      },
    );
  }

  static List<RouteRef> _dedupe(List<RouteRef> routes) {
    final seen = <String>{};
    return [for (final r in routes) if (seen.add(r.shortName)) r];
  }

  Future<void> _showFullMap(BuildContext context, Stop stop, Color color) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) => SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.92,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: TransitMap(
                    initialCenter: stop.position,
                    initialZoom: 16,
                    markers: [MapPoint(id: stop.id, position: stop.position, color: color, radius: 10, strokeWidth: 3)],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                  tooltip: MaterialLocalizations.of(ctx).closeButtonLabel,
                ),
              ),
              Positioned(
                left: 16,
                bottom: 16,
                right: 72,
                child: Material(
                  color: Theme.of(ctx).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Text(stop.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

/// Small muted accessibility line: "Accesible · Dato del feed no verificado".
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
