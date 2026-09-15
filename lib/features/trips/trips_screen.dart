import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../l10n/generated/app_localizations.dart';
import '../planner/planner_state.dart';

/// "Mis viajes": every scheduled trip with when it is pinned, what the planner last said ("sal ~7:12 ·
/// G30 + J23"), a switch, and swipe to delete. Tapping plans it now.
class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key, required this.cityId});
  final String cityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final trips = ref.watch(scheduledTripsProvider).where((t) => t.cityId == cityId).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tripsTitle),
        actions: [
          IconButton(
            key: const ValueKey('trips-refresh'),
            tooltip: l10n.tripsRefresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(scheduledTripsProvider.notifier).resync(),
          ),
        ],
      ),
      body: trips.isEmpty
          ? EmptyView(icon: Icons.alarm_rounded, message: l10n.tripsEmpty)
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 32),
              itemCount: trips.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => _TripTile(cityId: cityId, trip: trips[i]),
            ),
    );
  }
}

String scheduleLabel(ScheduledTrip t, AppLocalizations l10n, String locale) {
  if (t.date != null) return l10n.tripOnceOn(DateFormat.MMMEd(locale).format(t.date!));
  if (t.isDaily) return l10n.tripDaily;
  if (t.isWeekdays) return l10n.tripWeekdays;
  if (t.days.length == 2 && t.days.contains(DateTime.saturday) && t.days.contains(DateTime.sunday)) return l10n.tripWeekend;
  final monday = DateTime(2026, 9, 14);
  final names = DateFormat.E(locale);
  return (t.days.toList()..sort()).map((d) => names.format(monday.add(Duration(days: d - 1)))).join(' ');
}

class _TripTile extends ConsumerWidget {
  const _TripTile({required this.cityId, required this.trip});
  final String cityId;
  final ScheduledTrip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final t = trip;
    final time = TimeOfDay(hour: t.hour, minute: t.minute).format(context);
    final now = DateTime.now();
    final occ = t.nextOccurrence(now);
    final p = t.lastPlan;
    final String next;
    if (!t.enabled) {
      next = '';
    } else if (occ == null) {
      next = l10n.tripPast;
    } else if (p != null && p.occurrence == occ) {
      next = '${l10n.tripLeaveAround(formatClock(p.leaveAt, locale))}${p.routes.isEmpty ? '' : ' · ${p.routesLabel}'}';
    } else {
      next = l10n.tripPlanning;
    }
    return Dismissible(
      key: ValueKey('trip-${t.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: scheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_rounded, color: scheme.onErrorContainer),
      ),
      onDismissed: (_) {
        ref.read(scheduledTripsProvider.notifier).remove(t.id);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(l10n.tripDeleted)));
      },
      child: ListTile(
        leading: Icon(t.repeats ? Icons.repeat_rounded : Icons.event_rounded, color: t.enabled ? scheme.primary : scheme.outline),
        title: Text('${t.from.name} → ${t.to.name}', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w700, color: t.enabled ? null : scheme.outline)),
        subtitle: Text(
          [
            '${scheduleLabel(t, l10n, locale)} · ${t.arriveBy ? l10n.tripArriveAt(time) : l10n.tripDepartAt(time)}',
            if (next.isNotEmpty) next,
          ].join('\n'),
        ),
        isThreeLine: next.isNotEmpty,
        trailing: Switch(
          value: t.enabled,
          onChanged: (v) => ref.read(scheduledTripsProvider.notifier).setEnabled(t.id, v),
        ),
        onTap: () {
          final planner = ref.read(plannerProvider.notifier);
          planner.setFrom(t.from);
          planner.setTo(t.to);
          planner.setArriveBy(t.arriveBy);
          planner.setTime(occ);
          context.go('/$cityId/plan');
        },
      ),
    );
  }
}
