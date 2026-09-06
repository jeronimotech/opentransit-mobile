import '../models/models.dart';
import 'fare.dart';

/// Result sections in the order they are shown (Lote 1, Citymapper-style):
/// every itinerary belongs to exactly one scenario.
enum Scenario { fastest, lessWalking, fewerTransfers, cheapest, bike, onDemand }

class ScenarioGroup {
  const ScenarioGroup({required this.scenario, required this.best, this.rest = const []});
  final Scenario scenario;

  /// Shown expanded (full card).
  final Itinerary best;

  /// Shown as one-line rows under [best].
  final List<Itinerary> rest;

  List<Itinerary> get all => [best, ...rest];
}

/// Cost used for "Más barato": the fare amount, or for on-demand rides the
/// estimated ride price; unknown prices sort last.
num itineraryCost(Itinerary it, City? city) {
  final od = it.onDemand?.displayPrice;
  if (it.hasOnDemand && od != null) {
    final f = fareFor(it, city);
    final transit = (f?.breakdown.where((l) => l.kind == 'transit').fold<num>(0, (a, l) => a + l.amount)) ?? 0;
    return (f?.amount ?? transit) >= od.amount ? (f?.amount ?? transit) : transit + od.amount;
  }
  return fareFor(it, city)?.amount ?? double.infinity;
}

bool _usesBike(Itinerary it) =>
    it.hasRental || it.legs.any((l) => !l.transit && l.mode == TravelMode.bicycle);

int _byDuration(Itinerary a, Itinerary b) => a.durationSeconds.compareTo(b.durationSeconds);

/// Assigns each itinerary to exactly one scenario and returns the non-empty
/// groups in display order.
///
/// Transit itineraries: the fastest one anchors `fastest`; `lessWalking`,
/// `fewerTransfers` and `cheapest` only appear when some itinerary is strictly
/// better than the fastest on that axis (cheapest also needs differing
/// fares). Whatever is left joins `fastest` as one-line rows. Rides that use
/// a bike (own or shared) go to `bike`; taxi / ride-hailing ones to
/// `onDemand`.
List<ScenarioGroup> groupByScenario(List<Itinerary> its, {City? city}) {
  if (its.isEmpty) return const [];
  final onDemand = its.where((i) => i.hasOnDemand).toList()..sort(_byDuration);
  final bike = its.where((i) => !i.hasOnDemand && _usesBike(i)).toList()..sort(_byDuration);
  final pool = its.where((i) => !i.hasOnDemand && !_usesBike(i)).toList()..sort(_byDuration);

  final groups = <ScenarioGroup>[];
  if (pool.isNotEmpty) {
    final fastest = pool.removeAt(0);

    Itinerary? pick(bool Function(Itinerary) better, int Function(Itinerary, Itinerary) cmp) {
      final c = pool.where(better).toList();
      if (c.isEmpty) return null;
      c.sort((a, b) {
        final r = cmp(a, b);
        return r != 0 ? r : _byDuration(a, b);
      });
      final chosen = c.first;
      pool.remove(chosen);
      return chosen;
    }

    final lessWalking = pick(
      (i) => i.walkDistanceMeters < fastest.walkDistanceMeters,
      (a, b) => a.walkDistanceMeters.compareTo(b.walkDistanceMeters),
    );
    final fewerTransfers = pick(
      (i) => i.transfers < fastest.transfers,
      (a, b) => a.transfers.compareTo(b.transfers),
    );
    final fastestCost = itineraryCost(fastest, city);
    final costs = {for (final i in [fastest, ...pool]) itineraryCost(i, city)}
      ..removeWhere((c) => c == double.infinity);
    final cheapest = costs.length > 1
        ? pick(
            (i) => itineraryCost(i, city) < fastestCost,
            (a, b) => itineraryCost(a, city).compareTo(itineraryCost(b, city)),
          )
        : null;

    groups.add(ScenarioGroup(scenario: Scenario.fastest, best: fastest, rest: List.of(pool)));
    if (lessWalking != null) groups.add(ScenarioGroup(scenario: Scenario.lessWalking, best: lessWalking));
    if (fewerTransfers != null) groups.add(ScenarioGroup(scenario: Scenario.fewerTransfers, best: fewerTransfers));
    if (cheapest != null) groups.add(ScenarioGroup(scenario: Scenario.cheapest, best: cheapest));
  }
  if (bike.isNotEmpty) groups.add(ScenarioGroup(scenario: Scenario.bike, best: bike.first, rest: bike.skip(1).toList()));
  if (onDemand.isNotEmpty) {
    groups.add(ScenarioGroup(scenario: Scenario.onDemand, best: onDemand.first, rest: onDemand.skip(1).toList()));
  }
  return groups;
}
