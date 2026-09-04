import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

enum HubTile { plan, locate, nearby, routes, live, alerts, favorites }

/// Question-led home hub (TransMi App style): big tiles, one per task.
class HubTiles extends StatelessWidget {
  const HubTiles({super.key, required this.tiles, required this.onTap});
  final List<HubTile> tiles;
  final void Function(HubTile) onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.92,
      children: [
        for (final t in tiles)
          _Tile(
            key: ValueKey('hub-${t.name}'),
            icon: _icon(t),
            label: _label(t, l10n),
            primary: t == HubTile.plan,
            onTap: () => onTap(t),
          ),
      ],
    );
  }

  static IconData _icon(HubTile t) => switch (t) {
        HubTile.plan => Icons.alt_route_rounded,
        HubTile.locate => Icons.directions_bus_rounded,
        HubTile.nearby => Icons.near_me_rounded,
        HubTile.routes => Icons.route_rounded,
        HubTile.live => Icons.sensors_rounded,
        HubTile.alerts => Icons.campaign_rounded,
        HubTile.favorites => Icons.star_rounded,
      };

  static String _label(HubTile t, AppLocalizations l10n) => switch (t) {
        HubTile.plan => l10n.tilePlan,
        HubTile.locate => l10n.tileLocate,
        HubTile.nearby => l10n.tileNearby,
        HubTile.routes => l10n.tileRoutes,
        HubTile.live => l10n.tileLive,
        HubTile.alerts => l10n.tileAlerts,
        HubTile.favorites => l10n.tileFavorites,
      };
}

class _Tile extends StatelessWidget {
  const _Tile({super.key, required this.icon, required this.label, required this.onTap, this.primary = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = primary ? scheme.primary : scheme.surfaceContainerHigh;
    final fg = primary ? scheme.onPrimary : scheme.onSurface;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: primary ? fg : scheme.primary, size: 26),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.15)),
            ],
          ),
        ),
      ),
    );
  }
}
