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
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              SizedBox(
                height: 180,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                  child: TransitMap(
                    initialCenter: stop.position,
                    initialZoom: 15.5,
                    markers: [MapPoint(id: stop.id, position: stop.position, color: color, radius: 9, strokeWidth: 3)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
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
                    _AccessibilityChip(access: access),
                  ],
                ),
              ),
              if (boardEnabled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('locate-from-stop'),
                    onPressed: () => context.push('/$cityId/locate?stop=${Uri.encodeComponent(stop.id)}'),
                    icon: const Icon(Icons.directions_bus_outlined),
                    label: Text(l10n.locateTitle),
                  ),
                ),
              if (d.routes.isNotEmpty) ...[
                SectionTitle(l10n.routes),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final r in _dedupe(d.routes))
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => context.push('/$cityId/routes/${Uri.encodeComponent(r.id)}'),
                          child: RouteChip(r),
                        ),
                    ],
                  ),
                ),
              ],
              BoardView(cityId: cityId, stopId: stopId),
              _StopAlerts(cityId: cityId, stopId: stopId, routeIds: d.routes.map((r) => r.id).toSet()),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: _AccessibilityBlock(access: access),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: Text(stop.id, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.outline)),
              ),
            ],
          ),
        );
      },
    );
  }

  static List<RouteRef> _dedupe(List<RouteRef> routes) {
    final seen = <String>{};
    return [for (final r in routes) if (seen.add(r.shortName)) r];
  }
}

class _AccessibilityChip extends StatelessWidget {
  const _AccessibilityChip({required this.access});
  final StopAccessibility access;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (icon, text, color) = switch (access.wheelchair) {
      WheelchairAccess.accessible => (Icons.accessible, access.verified ? l10n.accessible : '${l10n.accessible} · ${l10n.accessibilityUnverified}', access.verified ? Colors.green.shade700 : Colors.orange.shade800),
      WheelchairAccess.notAccessible => (Icons.not_accessible, l10n.accessibilityNotAccessible, Colors.red.shade700),
      WheelchairAccess.unknown => (Icons.help_outline, l10n.accessibilityUnknown, scheme.outline),
    };
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(text, style: TextStyle(color: color, fontSize: 12)),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _AccessibilityBlock extends StatelessWidget {
  const _AccessibilityBlock({required this.access});
  final StopAccessibility access;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.accessible_forward, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.accessibility, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  switch (access.wheelchair) {
                    WheelchairAccess.accessible => l10n.accessible,
                    WheelchairAccess.notAccessible => l10n.accessibilityNotAccessible,
                    WheelchairAccess.unknown => l10n.accessibilityUnknown,
                  },
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${l10n.accessibilitySource(access.source)} · ${access.verified ? l10n.accessibilityVerified : (access.note ?? l10n.accessibilityUnverified)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: access.verified ? scheme.onSurfaceVariant : Colors.orange.shade800),
                ),
              ],
            ),
          ),
        ],
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
        for (final a in relevant)
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
