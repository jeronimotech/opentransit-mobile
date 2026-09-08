import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/providers.dart';
import '../../../core/utils/colors.dart';
import '../../../core/utils/geo.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../planner_actions.dart';

/// Leading glyph of a search result.
///
/// Contract v2.1: "a user must never mistake a street for a station". Stops and
/// stations keep the component colour in a filled **rounded square**; addresses,
/// streets and POIs get a flat **circle** on the surface colour with their own
/// icon. The shape carries the distinction even when the feed leaves
/// `component` null (which the live API does on `station` rows), so the two can
/// never collapse into the same grey badge.
class PlaceResultIcon extends ConsumerWidget {
  const PlaceResultIcon({super.key, required this.type, this.component, this.size = 36});
  final String type;
  final Component? component;
  final double size;

  static IconData iconFor(String type, Component? component, {City? city}) => switch (type) {
        'station' => Icons.subway_outlined,
        'stop' => componentIcon(component, city: city),
        'address' => Icons.home_outlined,
        'street' => Icons.signpost_outlined,
        _ => Icons.place_outlined,
      };

  bool get _isStop => type == 'stop' || type == 'station';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final city = ref.watch(currentCityProvider);
    final icon = iconFor(type, component, city: city);
    if (_isStop) {
      final color = componentColor(component, city: city);
      return Container(
        key: const ValueKey('place-icon-stop'),
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size * 0.28)),
        child: Icon(icon, color: onColor(color), size: size * 0.55),
      );
    }
    return Container(
      key: const ValueKey('place-icon-place'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Icon(icon, color: scheme.onSurfaceVariant, size: size * 0.55),
    );
  }
}

/// One row in the place search list.
///
/// Tapping the row runs the "obvious" action ([onPick] with the field the list
/// was opened for); the trailing overflow always offers **both** ends, so a
/// result can become the origin as easily as the destination.
class PlaceResultTile extends StatelessWidget {
  const PlaceResultTile({
    super.key,
    required this.name,
    required this.type,
    this.label,
    this.component,
    this.distanceMeters,
    required this.onPick,
    required this.defaultField,
    this.contentPadding,
    this.tileKey,
  });

  final String name;
  final String type;
  final String? label;
  final Component? component;
  final int? distanceMeters;
  final void Function(PlaceField field) onPick;

  /// End filled by a plain tap on the row; the overflow still offers both.
  final PlaceField defaultField;
  final EdgeInsetsGeometry? contentPadding;
  final Key? tileKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final typeLabel = placeTypeLabel(type, l10n);
    final parts = <String>[
      if (label != null && label!.trim().isNotEmpty) label!.trim() else typeLabel,
      if (distanceMeters != null) formatDistance(distanceMeters!),
    ];
    final subtitle = parts.join(' · ');
    return Semantics(
      // Screen readers hear the kind first: "Calle. Calle 85. …".
      label: '$typeLabel. $name. $subtitle',
      excludeSemantics: true,
      child: ListTile(
        key: tileKey,
        contentPadding: contentPadding,
        leading: PlaceResultIcon(type: type, component: component),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: () => onPick(defaultField),
        trailing: _BothEndsButton(name: name, onPick: onPick),
      ),
    );
  }
}

/// Overflow that keeps "use as origin" and "use as destination" one tap away.
class _BothEndsButton extends StatelessWidget {
  const _BothEndsButton({required this.name, required this.onPick});
  final String name;
  final void Function(PlaceField field) onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<PlaceField>(
      tooltip: l10n.placeOptions,
      icon: const Icon(Icons.more_vert),
      onSelected: onPick,
      itemBuilder: (_) => [
        PopupMenuItem(
          value: PlaceField.from,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.trip_origin, size: 20),
            title: Text(l10n.setAsOrigin),
          ),
        ),
        PopupMenuItem(
          value: PlaceField.to,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.flag_outlined, size: 20),
            title: Text(l10n.setAsDestination),
          ),
        ),
      ],
    );
  }
}
