import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/widgets/common.dart';
import '../../l10n/generated/app_localizations.dart';
import '../planner/widgets/itinerary_card.dart';
import '../planner/planner_state.dart';
import '../stops/widgets/board_view.dart';

/// A tool result, drawn with the same widgets the screens use so an answer is
/// tappable and leads into the real app instead of being a dead end.
///
/// An unknown kind renders nothing: a newer server may stream cards this build
/// cannot draw, and the prose beside them still stands on its own. The kinds
/// here are the ones the API actually emits (plural), with the singular
/// spellings normalised in [ChatCard.normalized].
class ChatCardView extends ConsumerWidget {
  const ChatCardView({super.key, required this.card, required this.city});
  final ChatCard card;
  final City city;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final map = card.map;
    if (map == null && card.payload is! List) return const SizedBox.shrink();

    switch (card.normalized) {
      case 'itineraries':
      case 'fares':
        final raw = (map?['itineraries'] as List?) ?? const [];
        final its = raw
            .whereType<Map>()
            .map((e) => Itinerary.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        if (its.isEmpty) return const SizedBox.shrink();
        return _Section(
          child: Column(
            children: [
              for (final it in its.take(2))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ItineraryCard(
                    itinerary: it,
                    onTap: () => _openPlan(context, ref, map),
                  ),
                ),
            ],
          ),
        );

      case 'board':
        final stop = map?['stop'] is Map
            ? Map<String, dynamic>.from(map!['stop'] as Map)
            : null;
        final stopId = stop?['id']?.toString();
        if (stopId == null) return const SizedBox.shrink();
        return _Section(
          child: BoardView(cityId: city.id, stopId: stopId, compact: true),
        );

      case 'next':
        final rows = (map?['next'] as List?) ?? const [];
        final route = map?['route'] is Map
            ? Map<String, dynamic>.from(map!['route'] as Map)
            : null;
        if (rows.isEmpty) return const SizedBox.shrink();
        return _Section(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in rows.whereType<Map>().take(3))
                _NextRow(
                  route: route,
                  row: Map<String, dynamic>.from(r),
                  city: city,
                ),
            ],
          ),
        );

      case 'alerts':
        final items = (map?['alerts'] as List?) ?? const [];
        if (items.isEmpty) return const SizedBox.shrink();
        return _Section(
          child: Column(
            children: [
              for (final a in items.whereType<Map>().take(3))
                _AlertRow(alert: TransitAlert.fromJson(Map<String, dynamic>.from(a))),
            ],
          ),
        );

      case 'place':
        final name = map?['name']?.toString();
        if (name == null) return const SizedBox.shrink();
        final stopId = map?['stopId']?.toString();
        return _Section(
          child: _PlaceRow(
            name: name,
            label: map?['label']?.toString(),
            onTap: stopId == null
                ? null
                : () => context.push('/${city.id}/stops/$stopId'),
          ),
        );

      case 'stops':
        final items = (map?['stops'] as List?) ?? const [];
        if (items.isEmpty) return const SizedBox.shrink();
        return _Section(
          child: Column(
            children: [
              for (final s in items.whereType<Map>().take(4))
                _PlaceRow(
                  name: s['name']?.toString() ?? '',
                  label: s['component']?.toString(),
                  onTap: s['id'] == null
                      ? null
                      : () => context.push('/${city.id}/stops/${s['id']}'),
                ),
            ],
          ),
        );

      case 'routes':
        final items = (map?['routes'] as List?) ?? const [];
        if (items.isEmpty) return const SizedBox.shrink();
        return _Section(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in items.whereType<Map>().take(8))
                _RouteChipButton(
                  route: Map<String, dynamic>.from(r),
                  city: city,
                ),
            ],
          ),
        );

      default:
        // vehicles, bikeStations and anything newer: the prose covers it.
        return const SizedBox.shrink();
    }
  }

  /// A card is not a dead end. This puts the same trip into the planner and
  /// opens the results screen, so everything downstream — fares, GO, sharing —
  /// behaves as if the trip had been typed in. The results screen reads the
  /// planner rather than the URL, so setting that state is what matters.
  void _openPlan(BuildContext context, WidgetRef ref, Map<String, dynamic>? map) {
    final from = placeFrom(map?['from']);
    final to = placeFrom(map?['to']);
    if (from == null || to == null) return;
    final planner = ref.read(plannerProvider.notifier);
    planner.setFrom(from);
    planner.setTo(to);
    // Hold the router before popping: the sheet's context is gone after it.
    final router = GoRouter.of(context);
    Navigator.of(context).maybePop();
    unawaited(planner.plan(city.id));
    router.push('/${city.id}/results');
  }

  /// The `from`/`to` of a plan card as a planner [Place]. Public so a test can
  /// pin the payload shape the API actually sends.
  static Place? placeFrom(Object? j) {
    if (j is! Map) return null;
    final lat = asDouble(j['lat']);
    final lon = asDouble(j['lon']);
    if (lat == null || lon == null) return null;
    return Place(
      name: j['name']?.toString() ?? '',
      position: LatLng(lat, lon),
      stopId: j['stopId']?.toString(),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: child,
      );
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.name, this.label, this.onTap});
  final String name;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(Icons.place_rounded, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600)),
                  if (label != null && label!.isNotEmpty)
                    Text(label!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}

class _NextRow extends StatelessWidget {
  const _NextRow({required this.route, required this.row, required this.city});
  final Map<String, dynamic>? route;
  final Map<String, dynamic> row;
  final City city;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final minutes = asInt(row['minutes']);
    final live = row['source']?.toString() == 'live';
    final ref = route == null ? null : RouteRef.fromJson(route!);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          if (ref != null) RouteChip(ref),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              minutes == null
                  ? '—'
                  : minutes <= 0
                      ? l10n.arrivingNow
                      : l10n.inMinutes(minutes),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          if (live) const LiveBadge(compact: true),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert});
  final TransitAlert alert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: scheme.tertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              alert.header,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteChipButton extends StatelessWidget {
  const _RouteChipButton({required this.route, required this.city});
  final Map<String, dynamic> route;
  final City city;

  @override
  Widget build(BuildContext context) {
    final id = route['id']?.toString();
    return InkWell(
      onTap: id == null ? null : () => context.push('/${city.id}/routes/$id'),
      borderRadius: BorderRadius.circular(999),
      child: RouteChip(RouteRef.fromJson(route)),
    );
  }
}
