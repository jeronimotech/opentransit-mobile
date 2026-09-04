import 'dart:math' as math;

import '../models/common.dart';

/// Great-circle distance in meters.
double haversineMeters(LatLng a, LatLng b) {
  const r = 6371000.0;
  final p1 = a.lat * math.pi / 180;
  final p2 = b.lat * math.pi / 180;
  final dp = p2 - p1;
  final dl = (b.lon - a.lon) * math.pi / 180;
  final h = math.sin(dp / 2) * math.sin(dp / 2) +
      math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
  return 2 * r * math.asin(math.sqrt(h));
}

/// Bounding box `[minLon, minLat, maxLon, maxLat]` around a set of points.
List<double>? boundsOf(Iterable<LatLng> pts) {
  double? minLat, minLon, maxLat, maxLon;
  for (final p in pts) {
    minLat = minLat == null ? p.lat : math.min(minLat, p.lat);
    maxLat = maxLat == null ? p.lat : math.max(maxLat, p.lat);
    minLon = minLon == null ? p.lon : math.min(minLon, p.lon);
    maxLon = maxLon == null ? p.lon : math.max(maxLon, p.lon);
  }
  if (minLat == null) return null;
  return [minLon!, minLat, maxLon!, maxLat!];
}

String formatDistance(int meters) =>
    meters >= 1000 ? '${(meters / 1000).toStringAsFixed(1)} km' : '$meters m';
