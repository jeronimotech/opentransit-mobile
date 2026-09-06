import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_event.dart';

/// Where batches go. The HTTP client posts to `/v1/cities/{city}/events`;
/// tests use a fake.
abstract class AnalyticsTransport {
  /// Returns the number of accepted events; throws on network failure.
  Future<int> send(String cityId, Map<String, dynamic> batch);
}

/// First-party, privacy-preserving analytics queue (CONTRACT-analytics v1.5).
///
/// * `sessionId` is random per app start; `cohortId` rotates every 30 days.
/// * Events are coarsened ([coarsenProps]) before they enter the queue.
/// * The queue is persisted (cap [cap]) and flushed every [flushInterval],
///   when [flushAt] events are pending, or when the app goes to background.
/// * Events older than 24 h are dropped; failures back off.
/// * With the opt-out on, nothing is queued or sent.
/// * Never throws and never blocks the UI.
class Analytics {
  Analytics({
    required SharedPreferences prefs,
    required AnalyticsTransport transport,
    required String? Function() cityId,
    String? Function()? locale,
    this.platform = 'ios',
    this.appVersion = '0',
    DateTime Function()? clock,
    Random? random,
    this.flushInterval = const Duration(seconds: 30),
    this.flushAt = 20,
    this.cap = 500,
    this.maxBatch = 50,
    bool autoFlush = true,
  })  : _prefs = prefs,
        _transport = transport,
        _cityId = cityId,
        _locale = locale ?? (() => null),
        _clock = clock ?? DateTime.now,
        _random = random ?? Random.secure() {
    sessionId = _newId();
    _queue = _loadQueue();
    if (autoFlush) _timer = Timer.periodic(flushInterval, (_) => flush());
  }

  static const _kQueue = 'analytics.queue';
  static const _kCohort = 'analytics.cohortId';
  static const _kCohortAt = 'analytics.cohortAt';
  static const _kEnabled = 'analytics.enabled';
  static const cohortRotation = Duration(days: 30);
  static const maxAge = Duration(hours: 24);

  final SharedPreferences _prefs;
  final AnalyticsTransport _transport;
  final String? Function() _cityId;
  final String? Function() _locale;
  final DateTime Function() _clock;
  final Random _random;
  final String platform;
  final String appVersion;
  final Duration flushInterval;
  final int flushAt;
  final int cap;
  final int maxBatch;

  late String sessionId;
  late List<AnalyticsEvent> _queue;
  Timer? _timer;
  bool _flushing = false;
  DateTime? _retryAt;
  int _failures = 0;

  /// Pending events (read-only view, for tests and the settings screen).
  List<AnalyticsEvent> get pending => List.unmodifiable(_queue);

  bool get enabled => _prefs.getBool(_kEnabled) ?? true;

  Future<void> setEnabled(bool v) async {
    try {
      await _prefs.setBool(_kEnabled, v);
      if (!v) {
        _queue = [];
        await _persist();
      }
    } catch (_) {}
  }

  /// Rotating anonymous cohort id (30 days), created on first use.
  String get cohortId {
    try {
      final id = _prefs.getString(_kCohort);
      final at = _prefs.getInt(_kCohortAt);
      final now = _clock();
      if (id != null && at != null && now.difference(DateTime.fromMillisecondsSinceEpoch(at)) < cohortRotation) {
        return id;
      }
      final fresh = _newId();
      _prefs.setString(_kCohort, fresh);
      _prefs.setInt(_kCohortAt, now.millisecondsSinceEpoch);
      return fresh;
    } catch (_) {
      return 'anon';
    }
  }

  /// Records one event. Cheap, synchronous, never throws.
  void track(String type, [Map<String, Object?> props = const {}]) {
    try {
      if (!enabled) return;
      final ev = AnalyticsEvent(type: type, at: _clock(), props: coarsenProps(props));
      _queue.add(ev);
      if (_queue.length > cap) _queue = _queue.sublist(_queue.length - cap);
      unawaited(_persist());
      if (_queue.length >= flushAt) unawaited(flush());
    } catch (_) {}
  }

  /// Sends what is pending (in batches of [maxBatch]). Safe to call often.
  Future<void> flush() async {
    if (_flushing || !enabled) return;
    final city = _cityId();
    if (city == null) return;
    final now = _clock();
    if (_retryAt != null && now.isBefore(_retryAt!)) return;
    _flushing = true;
    try {
      _queue.removeWhere((e) => now.difference(e.at) > maxAge);
      while (_queue.isNotEmpty) {
        final batch = _queue.take(maxBatch).toList();
        await _transport.send(city, _batchJson(batch));
        _queue = _queue.sublist(batch.length);
        _failures = 0;
        _retryAt = null;
        await _persist();
      }
    } catch (_) {
      _failures++;
      final backoff = Duration(seconds: min(600, 15 * (1 << min(_failures, 6))));
      _retryAt = _clock().add(backoff);
    } finally {
      _flushing = false;
    }
  }

  /// App moved to background: send what we have.
  Future<void> onAppBackground() => flush();

  /// "Borrar mis estadísticas": drops the queue and rotates the ids.
  Future<void> clearData() async {
    try {
      _queue = [];
      await _persist();
      await _prefs.remove(_kCohort);
      await _prefs.remove(_kCohortAt);
      sessionId = _newId();
    } catch (_) {}
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  Map<String, dynamic> _batchJson(List<AnalyticsEvent> events) => {
        'sessionId': sessionId,
        'cohortId': cohortId,
        'platform': platform,
        'appVersion': appVersion,
        'locale': _locale() ?? 'es',
        'sentAt': _clock().toIso8601String(),
        'events': [for (final e in events) e.toJson()],
      };

  List<AnalyticsEvent> _loadQueue() {
    try {
      final raw = _prefs.getString(_kQueue);
      if (raw == null) return [];
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return [for (final e in list) ?AnalyticsEvent.fromJson(e)];
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist() async {
    try {
      await _prefs.setString(_kQueue, jsonEncode([for (final e in _queue) e.toJson()]));
    } catch (_) {}
  }

  String _newId() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(20, (_) => alphabet[_random.nextInt(alphabet.length)]).join();
  }
}

/// Screen names reported for `screen_view`, derived from the router location.
String? screenNameFor(String location) {
  final path = Uri.parse(location).path;
  final segs = path.split('/').where((s) => s.isNotEmpty).toList();
  if (segs.isEmpty) return null;
  if (segs.first == 'cities') return 'cities';
  if (segs.length == 1) return 'home';
  return switch (segs[1]) {
    'plan' => 'plan',
    'search' => 'search',
    'results' => 'results',
    'itinerary' => segs.length >= 4 && segs[3] == 'go' ? 'go' : 'itinerary',
    'locate' => 'locate',
    'routes' => segs.length >= 3 ? 'route' : 'routes',
    'stops' => 'stop',
    'vehicles' => 'vehicle',
    'favorites' => 'favorites',
    'alerts' => 'alerts',
    'settings' => 'settings',
    'live' => 'home',
    _ => segs[1],
  };
}
