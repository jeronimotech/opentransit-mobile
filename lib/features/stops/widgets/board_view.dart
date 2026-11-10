import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/models.dart';
import '../../../core/analytics/analytics_event.dart';
import '../../../core/providers.dart';
import '../../../core/utils/text.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Arrival board grouped by route: "Siguiente en 5 min · luego 10, 15 y 20"
/// with a live/scheduled badge per time. Auto-refreshes via [boardProvider].
class BoardView extends ConsumerStatefulWidget {
  const BoardView({super.key, required this.cityId, required this.stopId, this.compact = false, this.onLocate});
  final String cityId;
  final String stopId;

  /// Compact rows without the section title (favorites screen).
  final bool compact;

  /// When set, a secondary "Ubica tu bus" text button sits in the header.
  final VoidCallback? onLocate;

  @override
  ConsumerState<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends ConsumerState<BoardView> {
  bool _tracked = false;

  String get cityId => widget.cityId;
  String get stopId => widget.stopId;
  bool get compact => widget.compact;
  VoidCallback? get onLocate => widget.onLocate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final key = CityKey(cityId, stopId);
    final board = ref.watch(boardProvider(key));
    final scheme = Theme.of(context).colorScheme;
    // Casablanca and Santiago publish no realtime at all. The city picker signals that by the
    // absence of a live badge, which is not something anyone reads; say it where the times are.
    final city = ref.watch(cityProvider(cityId)).asData?.value;
    final timetableOnly = city != null && !city.features.realtimeVehicles && !city.features.tripUpdates;
    if (!_tracked && board.hasValue && !compact) {
      _tracked = true;
      ref.read(analyticsProvider).track(Ev.boardView, {'stopId': stopId, 'component': board.value?.stop.component?.name});
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact)
          SectionTitle(
            l10n.board,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (board.asData != null) FreshnessLabel(cityId: cityId, freshness: board.asData!.value.freshness),
                if (onLocate != null) ...[
                  const SizedBox(width: 4),
                  TextButton.icon(
                    key: const ValueKey('locate-from-stop'),
                    style: TextButton.styleFrom(minimumSize: const Size(44, 44), visualDensity: VisualDensity.compact),
                    onPressed: onLocate,
                    icon: const Icon(Icons.directions_bus_outlined, size: 18),
                    label: Text(l10n.locateTitle),
                  ),
                ],
              ],
            ),
          ),
        if (timetableOnly)
          Padding(
            padding: EdgeInsets.fromLTRB(16, compact ? 2 : 4, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.schedule, size: 14, color: scheme.outline),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(l10n.boardTimetableOnly,
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, height: 1.3)),
                ),
              ],
            ),
          ),
        board.when(
          loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => compact
              ? Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(l10n.errorOffline, style: TextStyle(color: scheme.outline)))
              : ErrorView(error: e, onRetry: () => ref.invalidate(boardProvider(key))),
          data: (b) {
            if (b.rows.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Icon(Icons.departure_board_outlined, size: 18, color: scheme.outline),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l10n.noBoardContext, style: TextStyle(color: scheme.onSurfaceVariant))),
                ]),
              );
            }
            // The routes present on this board, in board order, deduped by id. A route with
            // two directions is one chip but keeps both of its rows when selected.
            final routes = <RouteRef>[];
            final seen = <String>{};
            for (final row in b.rows) {
              if (seen.add(row.route.id)) routes.add(row.route);
            }
            // Only worth a filter bar when there is a choice to make, and never on the
            // condensed favourites rows. A stale selection (route gone from the board) reads
            // as "all" so the list never goes mysteriously empty.
            final showFilter = !compact && routes.length >= 2;
            final selected = ref.watch(boardRouteFilterProvider(key));
            final active = showFilter && routes.any((r) => r.id == selected) ? selected : null;
            final rows = active == null ? b.rows : b.rows.where((row) => row.route.id == active).toList();
            final shown = compact ? rows.take(3) : rows;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showFilter) _RouteFilterBar(stopKey: key, routes: routes, selected: active),
                for (final row in shown) BoardRowTile(cityId: cityId, row: row, compact: compact),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Horizontal "Todas las rutas · 330 · B401 …" filter above the board. Selecting a route
/// narrows the arrival list and, through [boardRouteFilterProvider], the buses on the map;
/// tapping the active route again clears it. Our own pills, not a ChoiceChip, so each route
/// keeps its [RouteChip] identity (colour + icon) and the unselected ones simply dim.
class _RouteFilterBar extends ConsumerWidget {
  const _RouteFilterBar({required this.stopKey, required this.routes, required this.selected});
  final CityKey stopKey;
  final List<RouteRef> routes;
  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    void setFilter(String? id) => ref.read(boardRouteFilterProvider(stopKey).notifier).state = id;
    return SizedBox(
      height: 44,
      child: ListView(
        key: const ValueKey('board-route-filter'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        children: [
          _TextFilterPill(label: l10n.allRoutes, selected: selected == null, onTap: () => setFilter(null)),
          for (final r in routes) ...[
            const SizedBox(width: 8),
            _RouteFilterPill(
              route: r,
              selected: selected == r.id,
              dimmed: selected != null && selected != r.id,
              onTap: () => setFilter(selected == r.id ? null : r.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _TextFilterPill extends StatelessWidget {
  const _TextFilterPill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? scheme.onSurface : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? scheme.surface : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteFilterPill extends StatelessWidget {
  const _RouteFilterPill({required this.route, required this.selected, required this.dimmed, required this.onTap});
  final RouteRef route;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: dimmed ? 0.5 : 1,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? scheme.onSurface : Colors.transparent, width: 2),
            ),
            child: Center(child: RouteChip(route, dense: true)),
          ),
        ),
      ),
    );
  }
}

class BoardRowTile extends StatelessWidget {
  const BoardRowTile({super.key, required this.cityId, required this.row, this.compact = false});
  final String cityId;
  final BoardRow row;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final first = row.next.isEmpty ? null : row.next.first;
    final rest = row.next.skip(1).toList();
    final label = headsignLabel(row.headsign, towards: l10n.towards) ??
        headsignLabel(row.route.longName, towards: l10n.towards) ?? row.route.shortName;
    final window = row.route.serviceWindow;
    final etaText = first == null ? null : (first.minutes <= 0 ? l10n.arrivingNow : l10n.minutesOnly(first.minutes));
    final source = first?.source ?? 'scheduled';
    return Semantics(
      label: [
        row.route.shortName,
        label,
        if (etaText != null) '$etaText · ${SourceBadge.label(l10n, source)}',
      ].join(', '),
      child: ExcludeSemantics(
        child: InkWell(
          key: ValueKey('board-${row.route.id}-${row.headsign}'),
          onTap: () => context.push('/$cityId/locate?stop=${Uri.encodeComponent(_stopIdFrom(context))}&route=${Uri.encodeComponent(row.route.id)}'),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 6 : 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Large route chip on the left …
                RouteChip(row.route, dense: compact),
                const SizedBox(width: 12),
                // … headsign under it (single line) and the secondary times …
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: compact ? 13 : 15, fontWeight: FontWeight.w600)),
                      if (rest.isNotEmpty)
                        _ThenTimes(times: rest, compact: compact)
                      else if (window != null && !window.active)
                        ServiceHint(window, dense: true),
                      // Only when the agency published it for this very bus, which is why Bogota's
                      // rows are unchanged and Boston's gain a line. Left out of the compact
                      // favourites rows, where a third line costs more than it tells.
                      if (!compact && (first?.vehicle?.crowding.isKnown ?? false))
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: OccupancyBadge(occupancy: first!.vehicle!.crowding, dense: true),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // … and the first ETA big on the right, with the live blip.
                if (etaText != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        etaText,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: compact ? 18 : 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: source == 'scheduled'
                                  ? scheme.onSurface
                                  : SourceBadge.color(context, source),
                            ),
                      ),
                      // The pulse means a bus is reporting itself. An estimate is not reporting
                      // anything, so it gets the word instead — a pulsing dot would be the lie.
                      if (first!.isLive)
                        const LiveBadge(compact: true)
                      else if (first.isEstimated)
                        const SourceBadge(source: 'estimated', dense: true),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _stopIdFrom(BuildContext context) => _StopIdScope.of(context) ?? '';
}

/// "luego 5 · 7 min" where each number carries a filled dot when a bus is reporting and a hollow
/// ring when the time is our estimate — same shape, unfilled, because nothing confirmed it.
class _ThenTimes extends StatelessWidget {
  const _ThenTimes({required this.times, this.compact = false});
  final List<BoardTime> times;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final size = compact ? 11.0 : 12.0;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: size);
    // l10n.andThenTimes gives "y en {times} min": split around the placeholder.
    final template = l10n.andThenTimes('\u0000');
    final parts = template.split('\u0000');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(parts.first, style: muted),
        for (var i = 0; i < times.length; i++) ...[
          if (i > 0) Text(', ', style: muted),
          if (times[i].realtime) ...[
            SourceDot(source: times[i].source),
            const SizedBox(width: 3),
          ],
          Text('${times[i].minutes.clamp(0, 999)}',
              style: TextStyle(
                  color: times[i].realtime
                      ? SourceBadge.color(context, times[i].source)
                      : scheme.onSurfaceVariant,
                  fontSize: size,
                  fontWeight: FontWeight.w700)),
        ],
        if (parts.length > 1) Text(parts.last, style: muted),
      ],
    );
  }
}

/// Lets [BoardRowTile] know which stop it belongs to without threading ids.
class _StopIdScope extends InheritedWidget {
  const _StopIdScope({required this.stopId, required super.child});
  final String stopId;
  static String? of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<_StopIdScope>()?.stopId;
  @override
  bool updateShouldNotify(_StopIdScope old) => old.stopId != stopId;
}

/// Wrap a [BoardView] so its rows can deep-link into "Ubica tu bus".
class BoardScope extends StatelessWidget {
  const BoardScope({super.key, required this.stopId, required this.child});
  final String stopId;
  final Widget child;
  @override
  Widget build(BuildContext context) => _StopIdScope(stopId: stopId, child: child);
}
