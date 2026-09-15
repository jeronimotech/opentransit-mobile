import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/utils/notifications.dart';
import '../../l10n/generated/app_localizations.dart';
import '../planner/planner_state.dart';

/// "Programar viaje": pin a trip to a time — arrive by (the default: what people have fixed) or
/// leave at — on some weekdays or on one date. Saving asks for notification permission, arms the
/// reminders and says what will happen.
Future<bool> showScheduleTripSheet(BuildContext context, WidgetRef ref, {
  required String cityId,
  required Place from,
  required Place to,
  int hour = 8,
  int minute = 0,
  bool arriveBy = true,
  Set<int>? days,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _ScheduleTripSheet(cityId: cityId, from: from, to: to, hour: hour, minute: minute,
        arriveBy: arriveBy, days: days ?? {DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday, DateTime.friday}),
  );
  return saved ?? false;
}

class _ScheduleTripSheet extends ConsumerStatefulWidget {
  const _ScheduleTripSheet({required this.cityId, required this.from, required this.to, required this.hour,
      required this.minute, required this.arriveBy, required this.days});
  final String cityId;
  final Place from;
  final Place to;
  final int hour;
  final int minute;
  final bool arriveBy;
  final Set<int> days;

  @override
  ConsumerState<_ScheduleTripSheet> createState() => _ScheduleTripSheetState();
}

class _ScheduleTripSheetState extends ConsumerState<_ScheduleTripSheet> {
  late TimeOfDay _time = TimeOfDay(hour: widget.hour, minute: widget.minute);
  late bool _arriveBy = widget.arriveBy;
  late final Set<int> _days = {...widget.days};
  DateTime? _date;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final dayNames = DateFormat.E(locale);
    final monday = DateTime(2026, 9, 14); // a Monday: labels for the seven weekday chips
    final canSave = _date != null || _days.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.scheduleTrip, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${widget.from.name} → ${widget.to.name}', maxLines: 2, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, icon: const Icon(Icons.flag_rounded, size: 16), label: Text(l10n.scheduleArriveBy)),
                ButtonSegment(value: false, icon: const Icon(Icons.directions_walk_rounded, size: 16), label: Text(l10n.scheduleDepartAt)),
              ],
              selected: {_arriveBy},
              onSelectionChanged: (v) => setState(() => _arriveBy = v.first),
            ),
            const SizedBox(height: 12),
            ListTile(
              key: const ValueKey('schedule-time'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_rounded),
              title: Text(_arriveBy ? l10n.tripArriveAt(_time.format(context)) : l10n.tripDepartAt(_time.format(context)),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.edit_rounded, size: 18),
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: _time);
                if (t != null) setState(() => _time = t);
              },
            ),
            const SizedBox(height: 8),
            Text(l10n.scheduleRepeat, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var d = DateTime.monday; d <= DateTime.sunday; d++)
                  FilterChip(
                    key: ValueKey('schedule-day-$d'),
                    label: Text(dayNames.format(monday.add(Duration(days: d - 1))).substring(0, 1).toUpperCase()),
                    selected: _date == null && _days.contains(d),
                    onSelected: (on) => setState(() {
                      _date = null;
                      on ? _days.add(d) : _days.remove(d);
                    }),
                  ),
                ActionChip(
                  key: const ValueKey('schedule-once'),
                  avatar: Icon(Icons.event_rounded, size: 16, color: _date != null ? scheme.onPrimary : null),
                  backgroundColor: _date != null ? scheme.primary : null,
                  labelStyle: _date != null ? TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w700) : null,
                  label: Text(_date == null ? l10n.scheduleOnce : DateFormat.MMMEd(locale).format(_date!)),
                  onPressed: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(
                        context: context, initialDate: _date ?? now.add(const Duration(days: 1)),
                        firstDate: now, lastDate: now.add(const Duration(days: 365)));
                    if (d != null) setState(() => _date = d);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l10n.scheduleTripHint, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('schedule-save'),
                onPressed: canSave && !_saving ? _save : null,
                icon: const Icon(Icons.alarm_add_rounded),
                label: Text(l10n.scheduleSave),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final nav = Navigator.of(context);
    final granted = await LocalNotifications.instance.requestPermission();
    await LocalNotifications.instance.requestExactAlarms();
    final planner = ref.read(plannerProvider);
    final trip = ScheduledTrip(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      cityId: widget.cityId,
      from: widget.from,
      to: widget.to,
      hour: _time.hour,
      minute: _time.minute,
      arriveBy: _arriveBy,
      days: _date == null ? _days : const {},
      date: _date,
      modes: planner.modes.map((m) => m.wire).toList(),
      onDemand: planner.onDemand,
      createdAt: DateTime.now(),
    );
    await ref.read(scheduledTripsProvider.notifier).add(trip);
    if (!mounted) return;
    nav.pop(true);
    messenger?.showSnackBar(SnackBar(content: Text(granted ? l10n.scheduleSaved : l10n.scheduleNotifDenied)));
  }
}
