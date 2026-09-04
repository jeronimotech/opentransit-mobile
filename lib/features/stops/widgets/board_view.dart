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
    return ListTile(
      key: ValueKey('board-${row.route.id}-${row.headsign}'),
      dense: compact,
      leading: RouteChip(row.route, dense: compact),
      title: Row(
        children: [
          Expanded(
            child: Text(
              cleanHeadsign(row.headsign) == null ? (cleanHeadsign(row.route.longName) ?? '') : l10n.towards(cleanHeadsign(row.headsign)!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: compact ? 13 : 14),
            ),
          ),
          if (row.route.serviceWindow != null && !row.route.serviceWindow!.active)
            ServiceHint(row.route.serviceWindow, dense: true),
        ],
      ),
      subtitle: first == null
          ? null
          : Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                _TimeChip(t: first, primary: true),
                if (rest.isNotEmpty) ...[
                  Text(l10n.thenAt(''), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                  for (var i = 0; i < rest.length; i++) ...[
                    _TimeChip(t: rest[i]),
                    if (i < rest.length - 2) Text(',', style: TextStyle(color: scheme.onSurfaceVariant)),
                    if (i == rest.length - 2) Text('y', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                  ],
                ],
              ],
            ),
      trailing: first == null
          ? null
          : Semantics(
              label: '${first.minutes <= 0 ? l10n.arrivingNow : l10n.minutesOnly(first.minutes)} · ${first.realtime ? l10n.sourceLive : l10n.sourceScheduled}',
              child: ExcludeSemantics(
                child: Text(
                  first.minutes <= 0 ? l10n.arrivingNow : l10n.minutesOnly(first.minutes),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: first.realtime ? Colors.green.shade700 : scheme.onSurface,
                      ),
                ),
              ),
            ),
      onTap: () => context.push('/$cityId/locate?stop=${Uri.encodeComponent(_stopIdFrom(context))}&route=${Uri.encodeComponent(row.route.id)}'),
    );
  }

  String _stopIdFrom(BuildContext context) => _StopIdScope.of(context) ?? '';
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

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.t, this.primary = false});
  final BoardTime t;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final color = t.realtime ? Colors.green.shade700 : scheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (t.realtime) ...[
          const LiveBadge(compact: true),
          const SizedBox(width: 3),
        ] else
          Icon(Icons.schedule, size: 11, color: scheme.outline),
        if (!t.realtime) const SizedBox(width: 2),
        Text(
          primary ? l10n.nextIn(t.minutes.clamp(0, 999)) : '${t.minutes.clamp(0, 999)}',
          style: TextStyle(color: color, fontWeight: primary ? FontWeight.w700 : FontWeight.w600, fontSize: 12),
        ),
      ],
    );
  }
}
