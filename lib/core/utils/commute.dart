import '../models/models.dart';
import '../storage/favorites.dart';

/// Which way the Casa ⇄ Trabajo card points.
enum CommuteDirection { toWork, toHome }

/// Default direction for [now]: toward work in the morning, toward home from
/// noon on. Deliberately dumb and predictable — the card can always be
/// inverted by hand, and a wrong guess costs one tap.
CommuteDirection defaultCommuteDirection(DateTime now) =>
    now.hour < 12 ? CommuteDirection.toWork : CommuteDirection.toHome;

/// Origin/destination for a direction, or null when the pair is incomplete.
({Favorite from, Favorite to})? commuteEndpoints(
  CommuteDirection direction, {
  Favorite? home,
  Favorite? work,
}) {
  if (home == null || work == null) return null;
  return direction == CommuteDirection.toWork
      ? (from: home, to: work)
      : (from: work, to: home);
}

/// The alerts among [alerts] that touch any route used by [it].
///
/// Matching is by route id only: an alert that names no route (a station-wide
/// notice, say) is not attributed to the commute, because showing "Ruta con
/// desvío" for an unrelated alert would train people to ignore the badge.
List<TransitAlert> commuteAlerts(Itinerary it, List<TransitAlert> alerts) {
  final routes = {for (final l in it.legs) if (l.route != null) l.route!.id};
  if (routes.isEmpty) return const [];
  return [
    for (final a in alerts)
      if (a.routeIds.any(routes.contains)) a,
  ];
}
