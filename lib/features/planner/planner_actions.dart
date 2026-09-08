import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/storage/favorites.dart';
import '../../l10n/generated/app_localizations.dart';
import 'planner_state.dart';

/// Which end of the trip a place is being assigned to. Both ends are always
/// reachable: nothing in the app may offer only a destination (contract v2.1).
enum PlaceField {
  from,
  to;

  static PlaceField parse(Object? v) =>
      v?.toString() == 'from' ? PlaceField.from : PlaceField.to;

  String get wire => name;

  String label(AppLocalizations l10n) =>
      this == PlaceField.from ? l10n.fromLabel : l10n.toLabel;

  PlaceField get other => this == PlaceField.from ? PlaceField.to : PlaceField.from;
}

/// Reads the place currently held by [field].
Place? placeOf(PlannerState s, PlaceField field) =>
    field == PlaceField.from ? s.from : s.to;

/// The field an *implicit* pick should fill, given the field the UI was opened
/// for. It never silently overwrites: when [preferred] already holds a place
/// and the opposite end is empty, the empty end wins.
PlaceField implicitTarget(PlannerState s, PlaceField preferred) {
  if (placeOf(s, preferred) == null) return preferred;
  if (placeOf(s, preferred.other) == null) return preferred.other;
  return preferred;
}

/// Writes [place] into [field]. Returns true when the trip can be planned now.
///
/// This deliberately fires for a *replacement* too, not only for the pick that
/// first completes the pair: choosing a new destination for a trip that already
/// had one means you want that trip, and dragging an end already re-plans. The
/// web client behaves the same way, and the two must not diverge.
bool assignPlace(WidgetRef ref, PlaceField field, Place place) {
  final planner = ref.read(plannerProvider.notifier);
  if (field == PlaceField.from) {
    planner.setFrom(place);
  } else {
    planner.setTo(place);
  }
  return ref.read(plannerProvider).canPlan;
}

/// Records the O/D pair, runs the plan and opens the results screen.
///
/// Takes a [GoRouter] rather than a [BuildContext] so callers may pop their own
/// route first (a popped context cannot be used for navigation).
Future<void> runPlan(WidgetRef ref, GoRouter router, String cityId) async {
  final s = ref.read(plannerProvider);
  if (s.from == null || s.to == null) return;
  await ref.read(recentTripsProvider.notifier).add(RecentTrip(
      cityId: cityId, from: s.from!, to: s.to!, at: DateTime.now()));
  final res = await ref.read(plannerProvider.notifier).plan(cityId);
  // Navigate even on error so the results screen can show the retry state.
  if (res != null || ref.read(plannerProvider).result != null) {
    router.push('/$cityId/results');
  }
}

/// Location of the full-screen "choose on map" picker for [field], optionally
/// pre-centred on [at].
String pickOnMapLocation(String cityId, PlaceField field, {LatLng? at}) {
  final q = <String, String>{
    'field': field.wire,
    if (at != null) 'lat': at.lat.toString(),
    if (at != null) 'lon': at.lon.toString(),
  };
  return Uri(path: '/$cityId/pick', queryParameters: q).toString();
}

/// Human label for a geocode result type, used as the subtitle fallback and as
/// the screen-reader prefix so a street is never announced as a station.
String placeTypeLabel(String type, AppLocalizations l10n) => switch (type) {
      'station' => l10n.placeTypeStation,
      'stop' => l10n.placeTypeStop,
      'address' => l10n.placeTypeAddress,
      'street' => l10n.placeTypeStreet,
      _ => l10n.placeTypePlace,
    };
