import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/models.dart';
import '../../../core/providers.dart';
import '../../../core/utils/text.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Arrival board grouped by route: "Siguiente en 5 min · luego 10, 15 y 20"
/// with a live/scheduled badge per time. Auto-refreshes via [boardProvider].
class BoardView extends ConsumerWidget {
  const BoardView({super.key, required this.cityId, required this.stopId, this.compact = false, this.onLocate});
  final String cityId;
  final String stopId;

  /// Compact rows without the section title (favorites screen).
  final bool compact;

  /// When set, a secondary "Ubica tu bus" text button sits in the header.
  final VoidCallback? onLocate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final key = CityKey(cityId, stopId);
    final board = ref.watch(boardProvider(key));
    final scheme = Theme.of(context).colorScheme;

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
        board.when(
          loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => compact
              ? Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(l10n.errorOffline, style: TextStyle(color: scheme.outline)))
              : ErrorView(error: e, onRetry: () => ref.invalidate(boardProvider(key))),
          data: (b) => b.rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(l10n.noBoard, style: TextStyle(color: scheme.onSurfaceVariant)),
                )
              : Column(
                  children: [
                    for (final row in (compact ? b.rows.take(3) : b.rows))
                      BoardRowTile(cityId: cityId, row: row, compact: compact),
                  ],
                ),
        ),
      ],
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
    final headsign = cleanHeadsign(row.headsign) ?? cleanHeadsign(row.route.longName) ?? '';
    final window = row.route.serviceWindow;
    final etaText = first == null ? null : (first.minutes <= 0 ? l10n.arrivingNow : l10n.minutesOnly(first.minutes));
    return Semantics(
      label: [
        row.route.shortName,
        if (headsign.isNotEmpty) l10n.towards(headsign),
        if (etaText != null) '$etaText · ${first!.realtime ? l10n.sourceLive : l10n.sourceScheduled}',
      ].join(', '),
      child: ExcludeSemantics(
        child: ListTile(
          key: ValueKey('board-${row.route.id}-${row.headsign}'),
          dense: compact,
          minVerticalPadding: compact ? 4 : 8,
          leading: RouteChip(row.route, dense: compact),
          // Line 1: headsign (single line) … big first ETA on the right.
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  headsign.isEmpty ? row.route.shortName : l10n.towards(headsign),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: compact ? 13 : 14),
                ),
              ),
              if (etaText != null) ...[
                const SizedBox(width: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (first!.realtime) ...[const LiveBadge(compact: true), const SizedBox(width: 4)],
                    Text(
                      etaText,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: first.realtime ? Colors.green.shade700 : scheme.onSurface,
                          ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          // Line 2: "luego 5 · 7 min", a live dot only on realtime numbers; or
          // the service hint when the route is out of hours.
          subtitle: rest.isNotEmpty
              ? _ThenTimes(times: rest, compact: compact)
              : (window != null && !window.active ? ServiceHint(window, dense: true) : null),
          onTap: () => context.push('/$cityId/locate?stop=${Uri.encodeComponent(_stopIdFrom(context))}&route=${Uri.encodeComponent(row.route.id)}'),
        ),
      ),
    );
  }

  String _stopIdFrom(BuildContext context) => _StopIdScope.of(context) ?? '';
}

/// "luego 5 · 7 min" where each number carries a live dot only when realtime.
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
    // l10n.thenTimes gives "luego {times} min": split around the placeholder.
    final template = l10n.thenTimes('\u0000');
    final parts = template.split('\u0000');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(parts.first, style: muted),
        for (var i = 0; i < times.length; i++) ...[
          if (i > 0) Text(' · ', style: muted),
          if (times[i].realtime) ...[
            Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.green.shade600, shape: BoxShape.circle)),
            const SizedBox(width: 3),
          ],
          Text('${times[i].minutes.clamp(0, 999)}',
              style: TextStyle(
                  color: times[i].realtime ? Colors.green.shade700 : scheme.onSurfaceVariant,
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
