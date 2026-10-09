import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/providers.dart';
import '../../../core/utils/colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/text.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'equivalent_services.dart';

/// Everything needed to get on the right vehicle, in one card.
///
/// Asked for by TransMilenio against 1.16.0 (1.3): the code, the destination written on the bus,
/// where to wait and where to get off were spread across the leg detail, and the guided trip never
/// showed the destination at all — which is the one thing a rider compares against the vehicle in
/// front of them before stepping on.
class BoardingPass extends ConsumerWidget {
  const BoardingPass({super.key, required this.cityId, required this.leg, this.stopsAhead});

  final String cityId;
  final Leg leg;

  /// Calls between boarding and alighting, when the itinerary knows them.
  final int? stopsAhead;

  static Future<void> show(BuildContext context, {required String cityId, required Leg leg}) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => BoardingPass(
          cityId: cityId,
          leg: leg,
          stopsAhead: leg.intermediateStops.isEmpty ? null : leg.intermediateStops.length + 1,
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final scheme = Theme.of(context).colorScheme;
    final city = ref.watch(currentCityProvider);
    final color = leg.route == null ? scheme.primary : routeChipColors(leg.route!, city: city).bg;
    // The sign on the bus, which is what the rider is about to read: the headsign if the feed has
    // one, otherwise the far end of the route's own name.
    final destination = headsignLabel(leg.headsign, towards: (s) => s) ?? cleanHeadsign(leg.route?.longName);

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.boardingPass,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              Row(
                children: [
                  RouteChip(leg.route, mode: leg.mode),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      leg.route?.displayName ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              if (destination != null && destination.isNotEmpty) ...[
                const SizedBox(height: 14),
                _Field(
                  key: const ValueKey('boarding-destination'),
                  label: l10n.boardingDestination,
                  value: destination,
                  emphasis: true,
                  color: color,
                ),
              ],
              if (leg.route?.longName.isNotEmpty ?? false)
                _Field(label: l10n.boardingLine, value: leg.route!.longName),
              _Field(
                key: const ValueKey('boarding-wait'),
                label: l10n.boardingWaitAt,
                value: [
                  leg.from.name,
                  if (leg.from.stopCode?.isNotEmpty ?? false) leg.from.stopCode!,
                ].join(' · '),
                trailing: leg.from.departure == null ? null : formatClock(leg.from.departure!, locale),
              ),
              _Field(
                key: const ValueKey('boarding-getoff'),
                label: l10n.boardingGetOffAt,
                value: [
                  leg.to.name,
                  if (leg.to.stopCode?.isNotEmpty ?? false) leg.to.stopCode!,
                ].join(' · '),
                trailing: leg.to.arrival == null ? null : formatClock(leg.to.arrival!, locale),
              ),
              if (stopsAhead != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(l10n.stopsCount(stopsAhead!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ),
              if (leg.from.stopId != null && leg.to.stopId != null)
                EquivalentServices(
                  cityId: cityId,
                  fromStopId: leg.from.stopId!,
                  toStopId: leg.to.stopId!,
                  routeId: leg.route?.id,
                  boardingStopName: leg.from.name,
                  eager: true,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({super.key, required this.label, required this.value, this.trailing, this.emphasis = false, this.color});
  final String label;
  final String value;
  final String? trailing;
  final bool emphasis;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = emphasis
        ? Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: color)
        : Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(value, style: style)),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                Text(trailing!, style: Theme.of(context).textTheme.labelLarge),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
