import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Ask when the rider is heading back.
///
/// A return is thought about as "in an hour", not as a date, so the quick answers come first and
/// the full picker is the last resort. Reversing the endpoints and keeping the outbound hour —
/// which is what the swap button used to do — planned the way home for the morning you left.
class ReturnSheet extends StatelessWidget {
  const ReturnSheet._();

  /// Returns the chosen departure, or null if dismissed. A null *inside* the result means now, so
  /// the caller distinguishes "now" from "cancelled" rather than treating both as a default.
  static Future<({DateTime? at})?> show(BuildContext context) =>
      showModalBottomSheet<({DateTime? at})>(
        context: context,
        showDragHandle: true,
        builder: (_) => const ReturnSheet._(),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(l10n.returnWhen,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          ListTile(
            key: const ValueKey('return-now'),
            leading: const Icon(Icons.bolt_rounded),
            title: Text(l10n.returnNow),
            onTap: () => Navigator.pop(context, (at: null)),
          ),
          for (final h in const [1, 2, 4])
            ListTile(
              key: ValueKey('return-in-$h'),
              leading: const Icon(Icons.schedule_rounded),
              title: Text(l10n.returnInHours(h)),
              onTap: () => Navigator.pop(context, (at: now.add(Duration(hours: h)))),
            ),
          ListTile(
            key: const ValueKey('return-pick'),
            leading: const Icon(Icons.event_rounded),
            title: Text(l10n.returnPick),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: now,
                firstDate: now.subtract(const Duration(days: 1)),
                lastDate: now.add(const Duration(days: 30)),
              );
              if (date == null || !context.mounted) return;
              final time = await showTimePicker(
                  context: context, initialTime: TimeOfDay.fromDateTime(now));
              if (time == null || !context.mounted) return;
              Navigator.pop(context,
                  (at: DateTime(date.year, date.month, date.day, time.hour, time.minute)));
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
