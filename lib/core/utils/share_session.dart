import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models/models.dart';

/// Owns one shared-ETA link for the duration of a GO trip: creates it, pushes
/// progress on a timer, and revokes it on request.
///
/// The write key never leaves this object, and every failure is swallowed —
/// a trip must never break because the share endpoint is unhappy.
class ShareSession {
  ShareSession(this._api, this.cityId, {this.interval = const Duration(seconds: 30)});
  final ApiClient _api;
  final String cityId;
  final Duration interval;

  SharedTrip? _trip;
  Timer? _timer;
  ShareProgress Function()? _progress;
  bool _sending = false;

  SharedTrip? get trip => _trip;
  bool get isActive => _trip != null;
  String? get url => _trip?.url;

  /// Publishes [itinerary] and starts pushing whatever [progress] returns.
  Future<SharedTrip?> start(
    Itinerary itinerary, {
    String? label,
    required ShareProgress Function() progress,
  }) async {
    if (_trip != null) return _trip;
    try {
      final t = await _api.createShare(cityId, itinerary, label: label);
      _trip = t;
      _progress = progress;
      _timer = Timer.periodic(interval, (_) => push());
      return t;
    } catch (e) {
      debugPrint('share create failed: $e');
      return null;
    }
  }

  /// Sends the current progress once. Overlapping calls are dropped rather
  /// than queued: a late update is worthless.
  Future<void> push() async {
    final t = _trip;
    final p = _progress;
    if (t == null || p == null || _sending) return;
    _sending = true;
    try {
      await _api.patchShare(cityId, t.token, t.writeKey, p());
    } catch (e) {
      debugPrint('share patch failed: $e');
    } finally {
      _sending = false;
    }
  }

  /// Marks the trip finished for viewers, then stops the timer.
  Future<void> finish(ShareState state) async {
    final t = _trip;
    final p = _progress;
    _timer?.cancel();
    _timer = null;
    if (t == null || p == null) return;
    final last = p();
    try {
      await _api.patchShare(
        cityId,
        t.token,
        t.writeKey,
        ShareProgress(
          legIndex: last.legIndex,
          atStopId: last.atStopId,
          lat: last.lat,
          lon: last.lon,
          etaAt: last.etaAt,
          state: state,
        ),
      );
    } catch (e) {
      debugPrint('share finish failed: $e');
    }
  }

  /// Takes the page down.
  Future<void> revoke() async {
    final t = _trip;
    _timer?.cancel();
    _timer = null;
    _trip = null;
    _progress = null;
    if (t == null) return;
    try {
      await _api.revokeShare(cityId, t.token, t.writeKey);
    } catch (e) {
      debugPrint('share revoke failed: $e');
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
