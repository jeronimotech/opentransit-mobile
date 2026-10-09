import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../l10n/generated/app_localizations.dart';

/// The published schedule of one direction: the interval per hour, and every departure.
///
/// Asked for by TransMilenio against 1.16.0 (1.12). Two readings of the same data, because two
/// kinds of service share one feed: a trunk route runs every few minutes and the rider wants the
/// interval, a feeder runs eleven times a day and the rider wants the list. The sheet leads with
/// whichever fits and keeps the other below it.
class ScheduleSheet extends StatelessWidget {
  const ScheduleSheet({super.key, required this.schedule, required this.routeName});

  final PatternSchedule schedule;
  final String routeName;

  static Future<void> show(BuildContext context,
          {required PatternSchedule schedule, required String routeName}) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => ScheduleSheet(schedule: schedule, routeName: routeName),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final s = schedule;
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(routeName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            if (s.headsign != null && s.headsign!.isNotEmpty)
              Text(l10n.towards(s.headsign!),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            Text(
              [
                if (s.typicalHeadwayMinutes != null) l10n.everyMinutes(s.typicalHeadwayMinutes!),
                if (s.first != null && s.last != null) '${s.first} – ${s.last}',
                l10n.tripsPerDay(s.trips),
              ].join(' · '),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            // The intervals are ours, computed from the timetable; no feed of ours publishes them.
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(l10n.scheduleComputed,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ),
            const SizedBox(height: 16),
            Text(l10n.byHour, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            for (final b in s.bands)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(b.from, style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                    ),
                    Expanded(
                      child: Text(
                        b.headway == null
                            ? l10n.tripsPerDay(b.trips)
                            : '${l10n.everyMinutes(b.headway!.typical)} · ${l10n.tripsPerDay(b.trips)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            if (s.departures.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l10n.allDepartures, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final d in s.departures)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                      child: Text(d,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
