import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One favourite as the watch needs it: enough to draw a row and to ask the
/// API for departures without the watch knowing anything about our models.
@immutable
class WatchFavourite {
  const WatchFavourite({
    required this.kind,
    required this.id,
    required this.label,
    this.routeId,
    this.color,
    this.lat,
    this.lon,
  });

  /// "stop" or "route_at_stop".
  final String kind;
  final String id;
  final String label;
  final String? routeId;
  final String? color;
  final double? lat;
  final double? lon;

  Map<String, Object?> toJson() => {
        'kind': kind,
        'id': id,
        'label': label,
        if (routeId != null) 'routeId': routeId,
        if (color != null) 'color': color,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
      };
}

/// What the watch mirrors while GO runs.
@immutable
class WatchGoState {
  const WatchGoState({
    required this.active,
    this.nextStopName,
    this.minutesToNextStop,
    this.routeShortName,
    this.routeColor,
    this.etaAt,
    this.alight = false,
  });

  final bool active;
  final String? nextStopName;
  final int? minutesToNextStop;
  final String? routeShortName;
  final String? routeColor;
  final DateTime? etaAt;

  /// True once the traveller should get ready to get off; the watch turns
  /// this into a haptic tap, which is the whole point of wearing one.
  final bool alight;

  Map<String, Object?> toJson() => {
        'active': active,
        if (nextStopName != null) 'nextStopName': nextStopName,
        if (minutesToNextStop != null) 'minutesToNextStop': minutesToNextStop,
        if (routeShortName != null) 'routeShortName': routeShortName,
        if (routeColor != null) 'routeColor': routeColor,
        if (etaAt != null) 'etaEpochSeconds': etaAt!.millisecondsSinceEpoch / 1000.0,
        'alight': alight,
      };

  static const idle = WatchGoState(active: false);
}

/// Pushes a snapshot (city, API base, favourites, GO state) to the paired
/// watch. Silent no-op everywhere else, including iPhones with no watch.
class WatchSync {
  WatchSync({MethodChannel? channel, bool? platformSupported})
      : _channel = channel ?? const MethodChannel('opentransit/watch'),
        _platformSupported = platformSupported ?? (!kIsWeb && Platform.isIOS);

  static final WatchSync instance = WatchSync();

  final MethodChannel _channel;
  final bool _platformSupported;
  String? _lastPayload;

  Future<bool> isSupported() async {
    if (!_platformSupported) return false;
    return await _invoke<bool>('isSupported') ?? false;
  }

  /// Sends the snapshot. Identical consecutive snapshots are dropped so a GO
  /// session does not burn the watch's radio on every GPS fix.
  Future<bool> sync({
    required String cityId,
    required String cityName,
    required String apiBaseUrl,
    required List<WatchFavourite> favourites,
    WatchGoState go = WatchGoState.idle,
    bool analyticsEnabled = true,
  }) async {
    if (!await isSupported()) return false;
    final payload = <String, Object?>{
      'cityId': cityId,
      'cityName': cityName,
      'apiBaseUrl': apiBaseUrl,
      'favourites': [for (final f in favourites) f.toJson()],
      'go': go.toJson(),
      'analyticsEnabled': analyticsEnabled,
    };
    final fingerprint = payload.toString();
    if (fingerprint == _lastPayload) return true;
    final ok = await _invoke<bool>('sync', payload) ?? false;
    if (ok) _lastPayload = fingerprint;
    return ok;
  }

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } catch (e) {
      debugPrint('watch $method failed: $e');
      return null;
    }
  }
}
