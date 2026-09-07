import 'dart:math' as math;

import '../models/models.dart';
import 'geo.dart';

/// Radii offered by "Cerca de mí" (contract v1.9), in meters.
const List<int> nearMeRadii = [300, 600, 1000];
const int nearMeDefaultRadius = 600;

/// Whether a bus is coming toward the user, going away, or neither.
///
/// [unknown] is a real answer, not a fallback for laziness: a frame without a
/// bearing cannot say, and a bus crossing perpendicular is honestly neither.
enum Approach { approaching, away, unknown }

/// Half-width of the dead band around 90°, in degrees. Inside it the bus is
/// crossing rather than closing or opening, so the row shows no arrow.
const double _crossingBand = 10;

/// Bounding box `[minLon, minLat, maxLon, maxLat]` that encloses the circle of
/// [radiusMeters] around [center].
///
/// The stream subscribes to this box, so bandwidth tracks the radius instead of
/// the whole city. Longitude degrees shrink with latitude, hence the cosine;
/// near the poles it is clamped so the box never explodes to the whole world.
List<double> bboxAround(LatLng center, double radiusMeters) {
  const metersPerDegLat = 111320.0;
  final dLat = radiusMeters / metersPerDegLat;
  final cosLat = math.cos(center.lat * math.pi / 180).abs();
  final dLon = radiusMeters / (metersPerDegLat * math.max(cosLat, 0.01));
  return [
    center.lon - dLon,
    center.lat - dLat,
    center.lon + dLon,
    center.lat + dLat,
  ];
}

/// Initial great-circle bearing from [a] to [b], in degrees clockwise from north.
double bearingBetween(LatLng a, LatLng b) {
  final p1 = a.lat * math.pi / 180;
  final p2 = b.lat * math.pi / 180;
  final dl = (b.lon - a.lon) * math.pi / 180;
  final y = math.sin(dl) * math.cos(p2);
  final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
  final deg = math.atan2(y, x) * 180 / math.pi;
  return (deg + 360) % 360;
}

/// Smallest absolute angle between two bearings, in degrees (0..180).
double angleBetween(double a, double b) {
  final d = ((a - b).abs()) % 360;
  return d > 180 ? 360 - d : d;
}

/// Is the vehicle at [vehicle] heading toward [user]?
///
/// Compares the vehicle's own [bearing] with the bearing from the vehicle to
/// the user. Without a bearing the answer is [Approach.unknown] — the arrow is
/// omitted rather than guessed.
Approach approachOf(LatLng vehicle, double? bearing, LatLng user) {
  if (bearing == null) return Approach.unknown;
  final toUser = bearingBetween(vehicle, user);
  final diff = angleBetween(bearing, toUser);
  if (diff < 90 - _crossingBand) return Approach.approaching;
  if (diff > 90 + _crossingBand) return Approach.away;
  return Approach.unknown;
}

/// A live bus near the user, with everything the list row needs.
class NearbyVehicle {
  const NearbyVehicle({
    required this.vehicle,
    required this.distanceMeters,
    required this.approach,
  });

  final Vehicle vehicle;
  final int distanceMeters;
  final Approach approach;

  String get id => vehicle.id;
}

/// Buses inside [radiusMeters] of [center], nearest first.
///
/// [components] filters by component when non-empty; an empty set means "all",
/// which is what the chips show when nothing is selected.
List<NearbyVehicle> nearbyVehicles(
  Iterable<Vehicle> vehicles,
  LatLng center, {
  required double radiusMeters,
  Set<Component> components = const {},
  LatLng Function(Vehicle)? positionOf,
}) {
  final out = <NearbyVehicle>[];
  for (final v in vehicles) {
    if (components.isNotEmpty && !components.contains(v.component)) continue;
    final p = positionOf?.call(v) ?? v.position;
    final d = haversineMeters(p, center);
    if (d > radiusMeters) continue;
    out.add(NearbyVehicle(
      vehicle: v,
      distanceMeters: d.round(),
      approach: approachOf(p, v.bearing, center),
    ));
  }
  out.sort((a, b) {
    final c = a.distanceMeters.compareTo(b.distanceMeters);
    return c != 0 ? c : a.id.compareTo(b.id); // stable order between frames
  });
  return out;
}

/// The next radius up from [current], or null when already at the widest.
/// Drives the one-tap "amplía el radio" in the empty state.
int? widerRadius(int current) {
  for (final r in nearMeRadii) {
    if (r > current) return r;
  }
  return null;
}

/// Zoom that frames the whole radius circle on a phone screen.
///
/// A fixed zoom is wrong here: at zoom 16 a ~390 pt screen spans 928 m, so a
/// 600 m ring (1.2 km across) falls entirely outside the viewport and the map
/// claims "1 bus en 600 m" while showing neither the ring nor the bus. These
/// values put the ring at roughly 56 % of the screen width, which leaves room
/// for the sheet without shrinking it to a dot.
double zoomForRadius(int radiusMeters) => switch (radiusMeters) {
      <= 150 => 16.8,
      <= 300 => 15.8,
      <= 600 => 14.8,
      <= 1000 => 14.1,
      <= 2000 => 13.1,
      _ => 12.1,
    };
