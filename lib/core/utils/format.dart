import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';

String formatClock(DateTime t, String locale) =>
    DateFormat.Hm(locale).format(t.toLocal());

String formatDuration(int seconds, AppLocalizations l10n) {
  final m = (seconds / 60).round();
  if (m < 60) return l10n.minutesShort(m);
  return l10n.durationHm(m ~/ 60, m % 60);
}

/// "in N min" style countdown for departures; negative → "now".
String formatCountdown(DateTime t, AppLocalizations l10n, {DateTime? now}) {
  final diff = t.difference(now ?? DateTime.now()).inSeconds;
  if (diff < 45) return l10n.arrivingNow;
  return l10n.inMinutes((diff / 60).round());
}

String? formatDelay(int? delaySeconds, AppLocalizations l10n) {
  if (delaySeconds == null) return null;
  final m = (delaySeconds.abs() / 60).round();
  if (m == 0) return l10n.onTime;
  return delaySeconds > 0 ? l10n.delayedBy(m) : l10n.earlyBy(m);
}

String formatDateShort(DateTime t, String locale) =>
    DateFormat.MMMEd(locale).add_Hm().format(t.toLocal());
