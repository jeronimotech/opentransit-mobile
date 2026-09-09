import 'dart:math' as math;

import '../../core/models/models.dart';

/// The city a position belongs to, or null when it belongs to none.
///
/// A city's bbox is the honest test: it is the area its feed actually covers, so a
/// position inside it can be served. Nearest-centre alone would happily hand someone
/// in Montréal the Toronto app and then fail to plan a single trip, which is worse
/// than asking them to choose.
///
/// Overlapping boxes are possible once neighbouring cities are added, so the smallest
/// containing box wins — the more specific deployment is the better answer.
City? cityForPosition(Iterable<City> cities, LatLng at) {
  City? best;
  double bestArea = double.infinity;
  for (final c in cities) {
    if (!_contains(c.bbox, at)) continue;
    final area = _area(c.bbox);
    if (area < bestArea) {
      best = c;
      bestArea = area;
    }
  }
  return best;
}

/// Distance in kilometres from a position to a city's centre, for a "you look far
/// from here" hint. Not used to pick a city — see above.
double kmToCity(City c, LatLng at) {
  const r = 6371.0;
  final dLat = _rad(c.center.lat - at.lat);
  final dLon = _rad(c.center.lon - at.lon);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(at.lat)) * math.cos(_rad(c.center.lat)) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

bool _contains(List<double> bbox, LatLng at) {
  if (bbox.length < 4) return false;
  final [minLon, minLat, maxLon, maxLat] = bbox;
  return at.lon >= minLon && at.lon <= maxLon && at.lat >= minLat && at.lat <= maxLat;
}

double _area(List<double> b) => (b[2] - b[0]).abs() * (b[3] - b[1]).abs();

double _rad(double d) => d * math.pi / 180;
