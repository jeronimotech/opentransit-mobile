import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/storage/favorites.dart';
import '../../core/utils/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/transit_map.dart';
import '../../l10n/generated/app_localizations.dart';
import '../planner/planner_state.dart';

class StopDetailScreen extends ConsumerWidget {
  const StopDetailScreen({super.key, required this.cityId, required this.stopId});
  final String cityId;
  final String stopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final key = CityKey(cityId, stopId);
    final detail = ref.watch(stopDetailProvider(key));
    final scheme = Theme.of(context).colorScheme;

    return detail.when(
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(error: e, onRetry: () => ref.invalidate(stopDetailProvider(key))),
      ),
      data: (d) {
        final stop = d.stop;
        final fav = Favorite.stop(cityId, stop);
        final isFav = ref.watch(favoritesProvider).any((f) => f.key == fav.key);
        final color = componentColor(stop.component);
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
                onSelected: (v) {
                  final planner = ref.read(plannerProvider.notifier);
                  final place = Place(name: stop.name, position: stop.position, stopId: stop.id, component: stop.component);
                  if (v == 'to') {
                    planner.setTo(place);
                  } else {
                    planner.setFrom(place);
                  }
                  context.go('/$cityId/plan');
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'to', child: ListTile(leading: const Icon(Icons.flag_outlined), title: Text(l10n.goHere))),
                  PopupMenuItem(value: 'from', child: ListTile(leading: const Icon(Icons.trip_origin), title: Text(l10n.leaveFrom))),
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
                      avatar: Icon(stop.isStation ? Icons.subway_outlined : Icons.directions_bus, size: 16, color: onColor(color)),
                      label: Text(componentLabel(stop.component, l10n), style: TextStyle(color: onColor(color), fontWeight: FontWeight.w700)),
                      visualDensity: VisualDensity.compact,
                    ),
                    if (stop.code != null) Chip(label: Text(stop.code!), visualDensity: VisualDensity.compact),
                    if (stop.wheelchair == WheelchairAccess.accessible)
                      Chip(avatar: const Icon(Icons.accessible, size: 16), label: Text(l10n.accessible), visualDensity: VisualDensity.compact),
                  ],
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
                      for (final r in d.routes)
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => context.push('/$cityId/routes/${Uri.encodeComponent(r.id)}'),
                          child: RouteChip(r),
                        ),
                    ],
                  ),
                ),
              ],
              _Departures(cityId: cityId, stopId: stopId),
              _StopAlerts(cityId: cityId, stopId: stopId, routeIds: d.routes.map((r) => r.id).toSet()),
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
}

class _Departures extends ConsumerWidget {
  const _Departures({required this.cityId, required this.stopId});
  final String cityId;
  final String stopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final key = CityKey(cityId, stopId);
    final deps = ref.watch(departuresProvider(key));
    final locale = Localizations.localeOf(context).toString();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          l10n.departures,
          trailing: deps.asData == null
              ? null
              : Text(l10n.updatedAgo(DateTime.now().difference(deps.asData!.value.generatedAt).inSeconds.clamp(0, 999)),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
        ),
        deps.when(
          loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(departuresProvider(key))),
          data: (r) => r.departures.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(l10n.noDepartures, style: TextStyle(color: scheme.onSurfaceVariant)),
                )
              : Column(
                  children: [
                    for (final d in r.departures)
                      ListTile(
                        leading: RouteChip(d.route),
                        title: Text(
                          d.headsign == null ? d.route.longName : l10n.towards(d.headsign!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(decoration: d.canceled ? TextDecoration.lineThrough : null),
                        ),
                        subtitle: Row(
                          children: [
                            Text(formatClock(d.effectiveTime, locale)),
                            if (d.realtime && !d.canceled) ...[
                              const SizedBox(width: 8),
                              const LiveBadge(compact: true),
                              if (formatDelay(d.delaySeconds, l10n) case final s?) ...[
                                const SizedBox(width: 4),
                                Text(s, style: TextStyle(fontSize: 11, color: (d.delaySeconds ?? 0) > 60 ? Colors.orange.shade800 : Colors.green.shade700)),
                              ],
                            ] else if (!d.canceled) ...[
                              const SizedBox(width: 8),
                              Text(l10n.scheduled, style: TextStyle(fontSize: 11, color: scheme.outline)),
                            ],
                          ],
                        ),
                        trailing: d.canceled
                            ? Text(l10n.canceled, style: TextStyle(color: scheme.error, fontWeight: FontWeight.w700))
                            : Text(
                                formatCountdown(d.effectiveTime, l10n),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: d.realtime ? Colors.green.shade700 : scheme.onSurface,
                                    ),
                              ),
                        onTap: () => context.push('/$cityId/routes/${Uri.encodeComponent(d.route.id)}'),
                      ),
                  ],
                ),
        ),
      ],
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
