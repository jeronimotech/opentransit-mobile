import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// State of the three home-map layers.
class MapLayers {
  const MapLayers({required this.live, required this.pois, required this.network, this.zonal = false});
  final bool live;
  final bool pois;
  final bool network;

  /// Zonal/feeder shapes: off by default, they overlap heavily on corridors.
  final bool zonal;

  MapLayers copyWith({bool? live, bool? pois, bool? network, bool? zonal}) => MapLayers(
      live: live ?? this.live, pois: pois ?? this.pois, network: network ?? this.network, zonal: zonal ?? this.zonal);
}

/// Single "Capas" button (UX audit §A) opening a small popover with toggles for
/// live buses, station services and the route network.
class LayersButton extends StatelessWidget {
  const LayersButton({
    super.key,
    required this.layers,
    required this.onChanged,
    this.liveAvailable = true,
    this.poisAvailable = true,
  });
  final MapLayers layers;
  final void Function(MapLayers) onChanged;
  final bool liveAvailable;
  final bool poisAvailable;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final anyOn = layers.live || layers.pois;
    return Tooltip(
      message: l10n.layers,
      child: Material(
        color: scheme.surface,
        elevation: 4,
        shadowColor: Colors.black26,
        shape: const CircleBorder(),
        child: InkWell(
          key: const ValueKey('layers-button'),
          customBorder: const CircleBorder(),
          onTap: () => _open(context),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(Icons.layers_outlined, color: anyOn ? scheme.primary : scheme.onSurface),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          var cur = layers;
          void update(MapLayers next) {
            cur = next;
            onChanged(next);
            setSheet(() {});
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.layers, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  if (liveAvailable)
                    SwitchListTile(
                      key: const ValueKey('layer-live'),
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.directions_bus_rounded),
                      title: Text(l10n.layerLive),
                      subtitle: Text(l10n.layerLiveHint),
                      value: cur.live,
                      onChanged: (v) => update(cur.copyWith(live: v)),
                    ),
                  if (poisAvailable)
                    SwitchListTile(
                      key: const ValueKey('layer-pois'),
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.local_convenience_store_outlined),
                      title: Text(l10n.layerPois),
                      value: cur.pois,
                      onChanged: (v) => update(cur.copyWith(pois: v)),
                    ),
                  SwitchListTile(
                    key: const ValueKey('layer-network'),
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.timeline_rounded),
                    title: Text(l10n.layerNetwork),
                    subtitle: Text(l10n.layerNetworkHint),
                    value: cur.network,
                    onChanged: (v) => update(cur.copyWith(network: v)),
                  ),
                  SwitchListTile(
                    key: const ValueKey('layer-zonal'),
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.alt_route_rounded),
                    title: Text(l10n.layerNetworkZonal),
                    value: cur.zonal,
                    onChanged: cur.network ? (v) => update(cur.copyWith(zonal: v)) : null,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
