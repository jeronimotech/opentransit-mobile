import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/models.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Other services that run the same segment, so a rider can board whichever comes first.
///
/// Asked for by TransMilenio against 1.16.0 (1.1): an itinerary names one route per leg, so someone
/// at a trunk station lets three buses that would have taken them where they are going go by.
///
/// Two things keep it honest. A service boarding at another platform of the same station says so —
/// the alternative is useless if the rider stands in the wrong place. And when the server could
/// only match on stops rather than patterns it says that too, because "calls at both stops" is a
/// weaker claim than "runs this segment".
class EquivalentServices extends ConsumerStatefulWidget {
  const EquivalentServices({
    super.key,
    required this.cityId,
    required this.fromStopId,
    required this.toStopId,
    this.routeId,
    this.boardingStopName,
    this.eager = false,
  });

  final String cityId;
  final String fromStopId;
  final String toStopId;

  /// The leg's own route, left out of the answer.
  final String? routeId;

  /// The leg's boarding stop, to tell "same platform" from "another one".
  final String? boardingStopName;

  /// Ask right away. For a leg the rider is about to board; later legs wait for a tap, because the
  /// answer costs the server a pattern query per platform of the station.
  final bool eager;

  @override
  ConsumerState<EquivalentServices> createState() => _EquivalentServicesState();
}

class _EquivalentServicesState extends ConsumerState<EquivalentServices> {
  bool _asked = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (!widget.eager && !_asked) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const ValueKey('equivalents-ask'),
          onPressed: () => setState(() => _asked = true),
          icon: const Icon(Icons.swap_horiz, size: 18),
          label: Text(l10n.alsoServesAsk),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), visualDensity: VisualDensity.compact),
        ),
      );
    }
    final answer = ref
        .watch(segmentServicesProvider(
            SegmentKey(widget.cityId, widget.fromStopId, widget.toStopId, routeId: widget.routeId)))
        .asData
        ?.value;
    if (answer == null || answer.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        key: const ValueKey('equivalents'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.swap_horiz, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  answer.match == SegmentMatch.pattern ? l10n.alsoServes : l10n.alsoCallsAtBoth,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final s in answer.services) _ServiceRow(cityId: widget.cityId, service: s, boardingStopName: widget.boardingStopName),
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.cityId, required this.service, this.boardingStopName});
  final String cityId;
  final SegmentService service;
  final String? boardingStopName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final board = service.boardAt?.label;
    // Only worth saying when it is somewhere else: repeating the stop the rider is already at reads
    // as a difference that is not there.
    final elsewhere = board != null && boardingStopName != null && board != boardingStopName;
    final headsign = service.headsign;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => context.push('/$cityId/routes/${Uri.encodeComponent(service.route.id)}'),
        child: Row(
          children: [
            RouteChip(service.route, dense: true),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                elsewhere
                    ? l10n.alsoServesFrom(board)
                    : (headsign != null && headsign.isNotEmpty ? l10n.towards(headsign) : ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
