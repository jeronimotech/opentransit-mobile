import '../models/models.dart';
import 'geo.dart';
import 'polyline.dart';

/// Off-route detection. The user is "off route" once they have been further
/// than [thresholdMeters] from the current leg's geometry for [afterSeconds]
/// without interruption — a single bad GPS fix must never trigger a re-plan
/// prompt, which is why this is a sustained condition rather than a distance
/// test.
class OffRouteDetector {
  OffRouteDetector({this.thresholdMeters = 150, this.afterSeconds = 45});
  final double thresholdMeters;
  final int afterSeconds;

  DateTime? _awaySince;

  /// Feeds one fix. Returns true the moment the condition has held long
  /// enough; keeps returning true until [reset] or a fix back on route.
  bool update({required double metersFromRoute, required DateTime at}) {
    if (metersFromRoute <= thresholdMeters) {
      _awaySince = null;
      return false;
    }
    _awaySince ??= at;
    return at.difference(_awaySince!).inSeconds >= afterSeconds;
  }

  /// Forgets the current excursion (after the user dismisses the prompt).
  void reset() => _awaySince = null;

  /// Seconds the user has been away, for diagnostics.
  int awaySeconds(DateTime now) =>
      _awaySince == null ? 0 : now.difference(_awaySince!).inSeconds;
}

/// Distance from [here] to the closest point of [leg]'s drawn geometry, or to
/// the straight line between its endpoints when the leg carries no shape.
double metersFromLeg(Leg leg, LatLng here) {
  final pts = decodeGeometry(leg.geometry);
  if (pts.length < 2) {
    // No shape: fall back to the nearer endpoint, which is the honest answer
    // for a leg we cannot trace.
    final a = haversineMeters(here, leg.from.position);
    final b = haversineMeters(here, leg.to.position);
    return a < b ? a : b;
  }
  var best = double.infinity;
  for (var i = 0; i < pts.length - 1; i++) {
    final d = distanceToSegmentMeters(here, pts[i], pts[i + 1]);
    if (d < best) best = d;
  }
  return best;
}

/// What the trip actually cost the traveller, computed at the end of GO.
class TripReceipt {
  const TripReceipt({
    required this.plannedSeconds,
    required this.actualSeconds,
    required this.distanceMeters,
    required this.modes,
    required this.completed,
    this.fare,
    required this.co2SavedGrams,
  });

  final int plannedSeconds;
  final int actualSeconds;
  final int distanceMeters;
  final List<String> modes;
  final bool completed;
  final Fare? fare;

  /// Grams of CO₂ not emitted by not driving this trip.
  final int co2SavedGrams;

  /// Seconds over (positive) or under (negative) the plan.
  int get deltaSeconds => actualSeconds - plannedSeconds;
}

/// Average tailpipe CO₂ of a petrol car, grams per kilometre. Bogotá has no
/// published local factor, so this is the widely used European fleet average;
/// the receipt says "vs carro" rather than claiming precision.
const _carGramsPerKm = 170.0;

/// Emission factors for the modes we can actually be on, grams per km.
double _gramsPerKm(String mode) => switch (mode) {
      'WALK' || 'BICYCLE' || 'SCOOTER' || 'BICYCLE_RENTAL' || 'SCOOTER_RENTAL' => 0,
      'CAR' || 'CAR_ONDEMAND' => _carGramsPerKm,
      // Bus/rail per passenger-km, roughly a third of a car.
      _ => 60,
    };

/// Builds the end-of-trip receipt. [actualSeconds] is wall-clock time in GO;
/// distance is the itinerary's, since the traveller's own trace is not kept.
TripReceipt buildReceipt({
  required Itinerary itinerary,
  required int actualSeconds,
  required bool completed,
}) {
  var saved = 0.0;
  var distance = 0;
  for (final l in itinerary.legs) {
    distance += l.distanceMeters;
    final km = l.distanceMeters / 1000;
    final legMode = l.isOnDemand ? 'CAR_ONDEMAND' : l.mode.wire;
    saved += km * (_carGramsPerKm - _gramsPerKm(legMode));
  }
  return TripReceipt(
    plannedSeconds: itinerary.durationSeconds,
    actualSeconds: actualSeconds,
    distanceMeters: distance,
    modes: itinerary.modesUsed,
    completed: completed,
    fare: itinerary.fare,
    co2SavedGrams: saved < 0 ? 0 : saved.round(),
  );
}
