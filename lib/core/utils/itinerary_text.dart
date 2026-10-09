import '../../l10n/generated/app_localizations.dart';
import '../models/models.dart';
import 'format.dart';
import 'geo.dart';
import 'leg_steps.dart';

/// An itinerary as text a person can follow without opening anything.
///
/// Asked for by TransMilenio against 1.16.0 (1.10): sharing a trip sent a bare link, which is
/// useless to whoever receives it on a phone with no data, or who simply does not tap links. The
/// instructions travel in the message; the link goes at the end for whoever wants the live page.
///
/// Written as numbered steps rather than prose because that is how it gets read out loud over the
/// phone: "uno, camina hasta el portal; dos, toma el B74".
String itineraryAsText(
  Itinerary itinerary,
  AppLocalizations l10n,
  String locale, {
  String? fromName,
  String? toName,
  String? link,
}) {
  final legs = itinerary.legs;
  final origin = fromName ?? (legs.isEmpty ? '' : legs.first.from.name);
  final destination = toName ?? (legs.isEmpty ? '' : legs.last.to.name);
  final lines = <String>[
    '$origin → $destination',
    [
      '${formatClock(itinerary.startTime, locale)} – ${formatClock(itinerary.endTime, locale)}',
      formatDuration(itinerary.durationSeconds, l10n),
      if (itinerary.transfers > 0) l10n.transfersCount(itinerary.transfers),
    ].join(' · '),
    '',
  ];
  for (final (i, leg) in legs.indexed) {
    final time = formatClock(leg.startTime, locale);
    final what = StringBuffer('${i + 1}. $time  ${legInstruction(l10n, leg)}');
    if (leg.transit) {
      // The two things a rider needs for a transit leg and cannot infer: which vehicle, and where
      // to get off. `legInstruction` gives the first half, so the second half is added here.
      final route = leg.route?.displayName;
      final headsign = leg.headsign;
      what
        ..write(route == null ? '' : ' · $route')
        ..write(headsign == null || headsign.isEmpty ? '' : ' (${l10n.towards(headsign)})')
        ..write(' · ${l10n.getOffAt(leg.to.name)} ${formatClock(leg.endTime, locale)}');
    } else if (leg.distanceMeters > 0) {
      what.write(' · ${formatDistance(leg.distanceMeters)}');
    }
    lines.add(what.toString());
  }
  if (link != null && link.isNotEmpty) {
    lines
      ..add('')
      ..add(link);
  }
  return lines.join('\n');
}
