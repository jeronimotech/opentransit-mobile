import 'dart:math' as math;

import '../models/models.dart';

/// Smoothly moves vehicles between two consecutive frames.
///
/// The feed updates every ~15 s; drawing raw frames makes buses jump. The
/// interpolator keeps, per vehicle, the position it *showed last* and the
/// position the latest frame *wants*, and eases between them over
/// [duration] starting at the moment the frame arrived. A vehicle that jumped
/// further than [maxJumpMeters] (trip change, GPS glitch) snaps instead.
class VehicleInterpolator {
  VehicleInterpolator({
    this.duration = const Duration(seconds: 12),
    this.maxJumpMeters = 2500,
  });

  final Duration duration;
  final double maxJumpMeters;

  final Map<String, _Track> _tracks = {};
  int _seq = -1;

  int get trackedCount => _tracks.length;

  /// Registers a new frame at [at]. Returns true when something changed.
  bool ingest(VehicleFrame frame, DateTime at) {
    if (frame.seq == _seq) return false;
    _seq = frame.seq;
    final live = <String>{};
    for (final v in frame.vehicles.values) {
      live.add(v.id);
      final t = _tracks[v.id];
      if (t == null) {
        _tracks[v.id] = _Track(from: v.position, to: v.position, since: at);
        continue;
      }
      if (t.to == v.position) continue; // nothing new for this bus
      final current = t.positionAt(at, duration);
      final jump = _roughMeters(current, v.position);
      _tracks[v.id] = jump > maxJumpMeters
          ? _Track(from: v.position, to: v.position, since: at)
          : _Track(from: current, to: v.position, since: at);
    }
    _tracks.removeWhere((id, _) => !live.contains(id));
    return true;
  }

  /// Interpolated position of [id] at [at]; null when unknown.
  LatLng? positionAt(String id, DateTime at) =>
      _tracks[id]?.positionAt(at, duration);

  /// True while at least one vehicle is still moving toward its target.
  bool isAnimating(DateTime at) =>
      _tracks.values.any((t) => t.from != t.to && at.difference(t.since) < duration);

  /// Fraction of the way [id] is through its current segment (0..1).
  double progress(String id, DateTime at) {
    final t = _tracks[id];
    if (t == null) return 1;
    return t.fraction(at, duration);
  }

  void clear() {
    _tracks.clear();
    _seq = -1;
  }
}

class _Track {
  const _Track({required this.from, required this.to, required this.since});
  final LatLng from;
  final LatLng to;
  final DateTime since;

  double fraction(DateTime at, Duration d) {
    if (from == to || d.inMilliseconds == 0) return 1;
    final f = at.difference(since).inMilliseconds / d.inMilliseconds;
    if (f <= 0) return 0;
    if (f >= 1) return 1;
    // ease-in-out so buses do not start/stop abruptly
    return f < 0.5 ? 2 * f * f : 1 - (-2 * f + 2) * (-2 * f + 2) / 2;
  }

  LatLng positionAt(DateTime at, Duration d) {
    final f = fraction(at, d);
    if (f >= 1) return to;
    if (f <= 0) return from;
    return LatLng(from.lat + (to.lat - from.lat) * f, from.lon + (to.lon - from.lon) * f);
  }
}

/// Equirectangular approximation, plenty for jump detection.
double _roughMeters(LatLng a, LatLng b) {
  const m = 111320.0;
  final dy = (b.lat - a.lat) * m;
  final dx = (b.lon - a.lon) * m * 0.9962; // cos(4.6°) for Bogotá-ish latitudes
  return math.sqrt(dx * dx + dy * dy);
}
