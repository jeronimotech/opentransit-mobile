import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../utils/colors.dart';

/// Where a running trip stands, as the Live Activity shows it.
enum LiveTripState {
  onTime('on_time'),
  delayed('delayed'),
  arrived('arrived'),
  cancelled('cancelled');

  const LiveTripState(this.wire);
  final String wire;
}

/// The fixed part of a trip: what never changes while GO runs.
@immutable
class LiveTrip {
  const LiveTrip({
    required this.cityId,
    required this.tripLabel,
    required this.destination,
    this.routeShortName = '',
    this.routeColor = '#B71C1C',
  });

  final String cityId;
  final String tripLabel;
  final String destination;
  final String routeShortName;
  final String routeColor;

  Map<String, Object?> toArguments() => {
        'cityId': cityId,
        'tripLabel': tripLabel,
        'destination': destination,
        'routeShortName': routeShortName,
        'routeColor': routeColor,
      };
}

/// The moving part: pushed on every leg change or ETA refresh.
@immutable
class LiveTripUpdate {
  const LiveTripUpdate({
    required this.etaAt,
    required this.minutesToNextStop,
    required this.nextStopName,
    required this.legIndex,
    required this.totalLegs,
    this.state = LiveTripState.onTime,
  });

  final DateTime etaAt;
  final int minutesToNextStop;
  final String nextStopName;
  final int legIndex;
  final int totalLegs;
  final LiveTripState state;

  Map<String, Object?> toArguments() => {
        'etaEpochSeconds': etaAt.millisecondsSinceEpoch / 1000.0,
        'minutesToNextStop': minutesToNextStop,
        'nextStopName': nextStopName,
        'legIndex': legIndex,
        'totalLegs': totalLegs,
        'state': state.wire,
      };

  /// Two updates that render identically are not worth a platform hop; the
  /// system throttles activity updates and we call this on every GPS fix.
  bool rendersSameAs(LiveTripUpdate? other) =>
      other != null &&
      other.minutesToNextStop == minutesToNextStop &&
      other.nextStopName == nextStopName &&
      other.legIndex == legIndex &&
      other.state == state &&
      other.etaAt.difference(etaAt).inSeconds.abs() < 60;
}

/// iOS Live Activity / Dynamic Island control.
///
/// Every method is a no-op that resolves to `false` off iOS, on iOS below
/// 16.2, and when the user has Live Activities switched off — GO must never
/// depend on it.
class LiveActivity {
  LiveActivity({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('opentransit/live_activity');

  static final LiveActivity instance = LiveActivity();

  final MethodChannel _channel;
  bool _running = false;
  LiveTripUpdate? _last;

  bool get isRunning => _running;

  /// True only where an activity can actually be shown.
  Future<bool> isSupported() async {
    if (kIsWeb || !Platform.isIOS) return false;
    return await _invoke<bool>('isSupported') ?? false;
  }

  Future<bool> start(LiveTrip trip, LiveTripUpdate initial) async {
    if (!await isSupported()) return false;
    final ok = await _invoke<bool>('start', {
          ...trip.toArguments(),
          ...initial.toArguments(),
        }) ??
        false;
    _running = ok;
    _last = ok ? initial : null;
    return ok;
  }

  Future<bool> update(LiveTripUpdate u) async {
    if (!_running) return false;
    if (u.rendersSameAs(_last)) return true;
    final ok = await _invoke<bool>('update', u.toArguments()) ?? false;
    if (ok) _last = u;
    return ok;
  }

  Future<bool> end() async {
    if (!_running) return false;
    _running = false;
    _last = null;
    return await _invoke<bool>('end') ?? false;
  }

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null; // Platform without the bridge compiled in.
    } catch (e) {
      debugPrint('live activity $method failed: $e');
      return null;
    }
  }
}

/// Builds the fixed part from the itinerary the traveller is following: the
/// badge shows the first transit route, which is what they are looking for.
LiveTrip liveTripFor({
  required String cityId,
  required Itinerary itinerary,
  required String originName,
  required String destinationName,
  City? city,
}) {
  RouteRef? route;
  for (final l in itinerary.legs) {
    if (l.transit && l.route != null) {
      route = l.route;
      break;
    }
  }
  final bg = route == null ? null : routeChipColors(route, city: city).bg;
  return LiveTrip(
    cityId: cityId,
    tripLabel: '$originName → $destinationName',
    destination: destinationName,
    routeShortName: route?.shortName ?? '',
    routeColor: bg == null ? '#B71C1C' : hexOfColor(bg),
  );
}
