import '../models/models.dart';
import 'geo.dart';

/// Indexes of the stops that currently have a bus "on" them: for every live
/// vehicle, the closest stop of the pattern, provided it is within
/// [snapMeters]. A bus further than that from every stop is between stops and
/// deliberately shown nowhere rather than snapped to a misleading one.
Set<int> nearestStopIndexesFor(
  Iterable<Vehicle> vehicles,
  List<Stop> stops, {
  double snapMeters = 250,
}) {
  if (stops.isEmpty) return const {};
  final out = <int>{};
  for (final v in vehicles) {
    var bestIndex = -1;
    var bestDistance = double.infinity;
    for (var i = 0; i < stops.length; i++) {
      final d = haversineMeters(v.position, stops[i].position);
      if (d < bestDistance) {
        bestDistance = d;
        bestIndex = i;
      }
    }
    if (bestIndex >= 0 && bestDistance <= snapMeters) out.add(bestIndex);
  }
  return out;
}
