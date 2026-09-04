import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/storage/favorites.dart';
import '../../core/utils/colors.dart';
import '../../core/widgets/common.dart';
import '../../l10n/generated/app_localizations.dart';
import '../planner/planner_state.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key, required this.cityId});
  final String cityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final all = ref.watch(favoritesProvider).where((f) => f.cityId == cityId).toList();
    final stops = all.where((f) => f.type == FavoriteType.stop).toList();
    final routes = all.where((f) => f.type == FavoriteType.route).toList();
    final places = all.where((f) => f.type == FavoriteType.place).toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.favorites)),
      body: all.isEmpty
          ? EmptyView(icon: Icons.star_outline, message: l10n.noFavorites)
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                if (stops.isNotEmpty) SectionTitle(l10n.stops),
                for (final f in stops) _FavTile(fav: f, cityId: cityId),
                if (routes.isNotEmpty) SectionTitle(l10n.routes),
                for (final f in routes) _FavTile(fav: f, cityId: cityId),
                if (places.isNotEmpty) SectionTitle(l10n.places),
                for (final f in places) _FavTile(fav: f, cityId: cityId),
              ],
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
    final l10n = AppLocalizations.of(context);
    final color = fav.color != null ? colorFromHex(fav.color) : componentColor(fav.component);
    final icon = switch (fav.type) {
      FavoriteType.stop => Icons.directions_bus,
      FavoriteType.route => Icons.route,
      FavoriteType.place => Icons.place,
    };
    return Dismissible(
      key: ValueKey(fav.key),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => ref.read(favoritesProvider.notifier).remove(fav),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color, child: Icon(icon, color: onColor(color), size: 20)),
        title: Text(fav.name),
        subtitle: fav.subtitle == null ? null : Text(fav.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: fav.type == FavoriteType.route
            ? null
            : IconButton(
                tooltip: l10n.goHere,
                icon: const Icon(Icons.directions),
                onPressed: () {
                  ref.read(plannerProvider.notifier).setTo(fav.toPlace());
                  context.go('/$cityId/plan');
                },
              ),
        onTap: () => switch (fav.type) {
          FavoriteType.stop => context.go('/$cityId/stops/${Uri.encodeComponent(fav.id)}'),
          FavoriteType.route => context.go('/$cityId/routes/${Uri.encodeComponent(fav.id)}'),
          FavoriteType.place => () {
              ref.read(plannerProvider.notifier).setTo(fav.toPlace());
              context.go('/$cityId/plan');
            }(),
        },
      ),
    );
  }
}
