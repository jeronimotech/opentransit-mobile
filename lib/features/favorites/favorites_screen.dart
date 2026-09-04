import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/storage/favorites.dart';
import '../../core/utils/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../l10n/generated/app_localizations.dart';
import '../planner/planner_state.dart';
import '../stops/widgets/board_view.dart';

/// Typed favorites (Casa / Trabajo / custom), stops with their next buses,
/// routes with service hours, plus recent trips for one-tap replanning.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key, required this.cityId});
  final String cityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final all = ref.watch(favoritesProvider).where((f) => f.cityId == cityId).toList();
    final places = all.where((f) => f.type == FavoriteType.place).toList()
      ..sort((a, b) => a.kind.index.compareTo(b.kind.index));
    final stops = all.where((f) => f.type == FavoriteType.stop).toList();
    final routes = all.where((f) => f.type == FavoriteType.route).toList();
    final recents = ref.watch(recentTripsProvider).where((t) => t.cityId == cityId).toList();
    final home = places.where((f) => f.kind == FavoriteKind.home).firstOrNull;
    final work = places.where((f) => f.kind == FavoriteKind.work).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.favorites)),
      body: all.isEmpty && recents.isEmpty
          ? EmptyView(icon: Icons.star_outline, message: l10n.noFavorites)
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Expanded(child: _QuickPlace(cityId: cityId, kind: FavoriteKind.home, fav: home)),
                      const SizedBox(width: 10),
                      Expanded(child: _QuickPlace(cityId: cityId, kind: FavoriteKind.work, fav: work)),
                    ],
                  ),
                ),
                if (places.any((f) => f.kind == FavoriteKind.custom)) ...[
                  SectionTitle(l10n.places),
                  for (final f in places.where((f) => f.kind == FavoriteKind.custom)) _FavTile(fav: f, cityId: cityId),
                ],
                if (stops.isNotEmpty) ...[
                  SectionTitle(l10n.stops),
                  for (final f in stops) _StopFav(fav: f, cityId: cityId),
                ],
                if (routes.isNotEmpty) ...[
                  SectionTitle(l10n.routes),
                  for (final f in routes) _RouteFav(fav: f, cityId: cityId),
                ],
                if (recents.isNotEmpty) ...[
                  SectionTitle(
                    l10n.recentTrips,
                    trailing: TextButton(
                      onPressed: () => ref.read(recentTripsProvider.notifier).clear(cityId),
                      child: Text(l10n.clearRecent),
                    ),
                  ),
                  for (final t in recents) _RecentTile(trip: t, cityId: cityId),
                ],
              ],
            ),
    );
  }
}

class _QuickPlace extends ConsumerWidget {
  const _QuickPlace({required this.cityId, required this.kind, required this.fav});
  final String cityId;
  final FavoriteKind kind;
  final Favorite? fav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final label = kind == FavoriteKind.home ? l10n.favHome : l10n.favWork;
    final icon = kind == FavoriteKind.home ? Icons.home_rounded : Icons.work_rounded;
    return Material(
      key: ValueKey('quick-${kind.name}'),
      color: fav == null ? scheme.surfaceContainerLow : scheme.primaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (fav == null) {
            context.push('/$cityId/search?field=to&saveAs=${kind.name}');
            return;
          }
          ref.read(plannerProvider.notifier).setTo(fav!.toPlace());
          context.go('/$cityId/plan');
        },
        onLongPress: fav == null ? null : () => ref.read(favoritesProvider.notifier).remove(fav!),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: fav == null ? scheme.onSurfaceVariant : scheme.onPrimaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(fav?.subtitle ?? fav?.name ?? (kind == FavoriteKind.home ? l10n.setHome : l10n.setWork),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavTile extends ConsumerWidget {
  const _FavTile({required this.fav, required this.cityId});
  final Favorite fav;
  final String cityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(fav.key),
      direction: DismissDirection.endToStart,
      background: _dismissBg(context),
      onDismissed: (_) => ref.read(favoritesProvider.notifier).remove(fav),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: scheme.secondaryContainer, child: Icon(iconByName(fav.icon), color: scheme.onSecondaryContainer, size: 20)),
        title: Text(fav.name),
        subtitle: fav.subtitle == null ? null : Text(fav.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.directions),
        onTap: () {
          ref.read(plannerProvider.notifier).setTo(fav.toPlace());
          context.go('/$cityId/plan');
        },
      ),
    );
  }
}

class _StopFav extends ConsumerWidget {
  const _StopFav({required this.fav, required this.cityId});
  final Favorite fav;
  final String cityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Dismissible(
      key: ValueKey(fav.key),
      direction: DismissDirection.endToStart,
      background: _dismissBg(context),
      onDismissed: (_) => ref.read(favoritesProvider.notifier).remove(fav),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: ComponentBadge(fav.component),
            title: Text(fav.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: fav.subtitle == null ? null : Text(fav.subtitle!),
            trailing: IconButton(
              tooltip: l10n.locateTitle,
              icon: const Icon(Icons.directions_bus_outlined),
              onPressed: () => context.push('/$cityId/locate?stop=${Uri.encodeComponent(fav.id)}'),
            ),
            onTap: () => context.go('/$cityId/stops/${Uri.encodeComponent(fav.id)}'),
          ),
          // Live context: the stop's next buses right on the favorites screen.
          BoardScope(stopId: fav.id, child: BoardView(cityId: cityId, stopId: fav.id, compact: true)),
          const Divider(height: 12),
        ],
      ),
    );
  }
}

class _RouteFav extends ConsumerWidget {
  const _RouteFav({required this.fav, required this.cityId});
  final Favorite fav;
  final String cityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    // Service window comes from the routes catalogue (cached, cheap).
    final route = ref.watch(routesProvider(cityId)).asData?.value.where((r) => r.id == fav.id).firstOrNull;
    final w = route?.serviceWindow;
    return Dismissible(
      key: ValueKey(fav.key),
      direction: DismissDirection.endToStart,
      background: _dismissBg(context),
      onDismissed: (_) => ref.read(favoritesProvider.notifier).remove(fav),
      child: ListTile(
        leading: RouteChip(route ?? RouteRef(id: fav.id, shortName: fav.name, longName: fav.subtitle ?? '', color: fav.color ?? '#607D8B', textColor: '#FFFFFF', mode: TravelMode.bus, agencyId: '', component: fav.component)),
        title: Text(fav.subtitle ?? fav.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: w == null
            ? null
            : (w.active
                ? Text('${l10n.serviceHours}: ${w.start} – ${w.end}', style: TextStyle(color: scheme.onSurfaceVariant))
                : ServiceHint(w, dense: true)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/$cityId/routes/${Uri.encodeComponent(fav.id)}'),
      ),
    );
  }
}

class _RecentTile extends ConsumerWidget {
  const _RecentTile({required this.trip, required this.cityId});
  final RecentTrip trip;
  final String cityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context).toString();
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      key: ValueKey('recent-${trip.key}'),
      leading: CircleAvatar(backgroundColor: scheme.surfaceContainerHighest, child: Icon(Icons.history, color: scheme.onSurfaceVariant, size: 20)),
      title: Text('${trip.from.name} → ${trip.to.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(formatDateShort(trip.at, locale), style: TextStyle(color: scheme.onSurfaceVariant)),
      trailing: const Icon(Icons.replay),
      onTap: () async {
        final planner = ref.read(plannerProvider.notifier);
        planner.setFrom(trip.from);
        planner.setTo(trip.to);
        await planner.plan(cityId);
        if (context.mounted) context.go('/$cityId/results');
      },
    );
  }
}

Widget _dismissBg(BuildContext context) => Container(
      color: Theme.of(context).colorScheme.errorContainer,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      child: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.onErrorContainer),
    );
