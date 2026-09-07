import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'notifications.dart';

/// Polls the city's alerts while the app is alive and raises a **local**
/// notification for each alert that touches a saved route whose schedule
/// allows it. Deliberately not a background service: no push infrastructure,
/// no wake-ups, nothing leaves the device.
class RouteAlertWatcher {
  RouteAlertWatcher(this._ref, {this.interval = const Duration(minutes: 5)});
  final Ref _ref;
  final Duration interval;
  Timer? _timer;
  bool _running = false;

  /// Notification ids for route alerts start above the follow-along ones.
  static const _baseNotificationId = 2000;
  int _nextId = _baseNotificationId;

  /// Localised title, injected by the app root because the watcher has no
  /// `BuildContext`. `{route}` is replaced by the route's short name.
  String Function(String route)? titleBuilder;

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(interval, (_) => check());
    // A first pass shortly after launch, once the city is settled.
    Timer(const Duration(seconds: 20), check);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// One pass. Safe to call at any time; never throws.
  Future<void> check() async {
    if (_running) return;
    _running = true;
    try {
      final cityId = _ref.read(settingsProvider).cityId;
      if (cityId == null) return;
      final repo = _ref.read(routeAlertsRepositoryProvider);
      if (repo.schedules(cityId).isEmpty) return;

      final alerts = await _ref.read(apiClientProvider).alerts(cityId);
      final now = DateTime.now();
      final hits = repo.pending(cityId, alerts, now);
      if (hits.isEmpty) return;

      for (final h in hits) {
        final route = h.alert.routes.where((r) => r.id == h.routeId).firstOrNull;
        await LocalNotifications.instance.show(
          _nextId++,
          _title(route?.shortName ?? h.routeId),
          h.alert.header,
        );
      }
      await repo.record(hits, now);
    } catch (e) {
      debugPrint('route alert check failed: $e');
    } finally {
      _running = false;
    }
  }

  String _title(String route) => titleBuilder?.call(route) ?? route;
}

final routeAlertWatcherProvider = Provider<RouteAlertWatcher>((ref) {
  final w = RouteAlertWatcher(ref);
  ref.onDispose(w.stop);
  return w;
});
