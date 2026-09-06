import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/analytics/analytics.dart';
import 'package:opentransit_mobile/core/analytics/analytics_event.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTransport implements AnalyticsTransport {
  final List<Map<String, dynamic>> batches = [];
  final List<String> cities = [];
  bool fail = false;
  @override
  Future<int> send(String cityId, Map<String, dynamic> batch) async {
    if (fail) throw Exception('offline');
    cities.add(cityId);
    batches.add(batch);
    return (batch['events'] as List).length;
  }
}

Future<(Analytics, _FakeTransport, SharedPreferences)> _make({
  DateTime Function()? clock,
  String? city = 'bogota',
  Map<String, Object> initial = const {},
  int flushAt = 20,
}) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final t = _FakeTransport();
  final a = Analytics(
    prefs: prefs,
    transport: t,
    cityId: () => city,
    locale: () => 'es',
    platform: 'ios',
    appVersion: '1.5.0',
    clock: clock,
    random: Random(1),
    autoFlush: false,
    flushAt: flushAt,
  );
  return (a, t, prefs);
}

void main() {
  test('coarsens coordinates to 3 decimals and drops nulls', () {
    final p = coarsenProps({'fromLat': 4.7546123, 'fromLon': -74.0459876, 'lat': 4.65, 'label': 'Portal', 'x': null});
    expect(p['fromLat'], 4.755);
    expect(p['fromLon'], -74.046);
    expect(p['lat'], 4.65);
    expect(p['label'], 'Portal');
    expect(p.containsKey('x'), isFalse);
  });

  test('queues, persists and flushes in one batch with session and cohort ids', () async {
    final (a, t, prefs) = await _make();
    a.track(Ev.planRequest, {'fromLat': 4.7546123, 'modes': ['BUS']});
    a.track(Ev.screenView, {'screen': 'home'});
    expect(a.pending.length, 2);
    expect(prefs.getString('analytics.queue'), contains('plan_request'));
    await a.flush();
    expect(a.pending, isEmpty);
    expect(t.cities, ['bogota']);
    final b = t.batches.single;
    expect(b['sessionId'], a.sessionId);
    expect(b['cohortId'], a.cohortId);
    expect(b['platform'], 'ios');
    expect(b['appVersion'], '1.5.0');
    expect((b['events'] as List).length, 2);
    expect(((b['events'] as List).first as Map)['props']['fromLat'], 4.755);
    expect(prefs.getString('analytics.queue'), '[]');
  });

  test('auto-flushes when flushAt events are pending', () async {
    final (a, t, _) = await _make(flushAt: 3);
    a.track('a');
    a.track('b');
    expect(t.batches, isEmpty);
    a.track('c');
    await Future<void>.delayed(Duration.zero);
    expect(t.batches.length, 1);
    expect((t.batches.single['events'] as List).length, 3);
  });

  test('opt-out drops the queue and records nothing', () async {
    final (a, t, _) = await _make();
    a.track('before');
    await a.setEnabled(false);
    expect(a.enabled, isFalse);
    expect(a.pending, isEmpty);
    a.track('after');
    await a.flush();
    expect(a.pending, isEmpty);
    expect(t.batches, isEmpty);
    await a.setEnabled(true);
    a.track('again');
    await a.flush();
    expect(t.batches.length, 1);
  });

  test('network failure keeps events and backs off, then retries', () async {
    var now = DateTime(2026, 9, 6, 10);
    final (a, t, _) = await _make(clock: () => now);
    t.fail = true;
    a.track('x');
    await a.flush();
    expect(a.pending.length, 1);
    t.fail = false;
    await a.flush(); // still backing off
    expect(t.batches, isEmpty);
    now = now.add(const Duration(minutes: 1));
    await a.flush();
    expect(t.batches.length, 1);
    expect(a.pending, isEmpty);
  });

  test('events older than 24 h are dropped, queue is capped', () async {
    var now = DateTime(2026, 9, 6, 10);
    final (a, t, _) = await _make(clock: () => now);
    a.track('old');
    now = now.add(const Duration(hours: 25));
    a.track('fresh');
    await a.flush();
    expect((t.batches.single['events'] as List).map((e) => e['type']), ['fresh']);
    for (var i = 0; i < 600; i++) {
      a.track('e$i');
    }
    expect(a.pending.length, 500);
    expect(a.pending.first.type, 'e100');
  });

  test('cohort id rotates every 30 days and clearData renews everything', () async {
    var now = DateTime(2026, 9, 6, 10);
    final (a, _, prefs) = await _make(clock: () => now);
    final c1 = a.cohortId;
    expect(a.cohortId, c1);
    now = now.add(const Duration(days: 29));
    expect(a.cohortId, c1);
    now = now.add(const Duration(days: 2));
    final c2 = a.cohortId;
    expect(c2, isNot(c1));
    final s1 = a.sessionId;
    a.track('x');
    await a.clearData();
    expect(a.pending, isEmpty);
    expect(prefs.getString('analytics.cohortId'), isNull);
    expect(a.cohortId, isNot(c2));
    expect(a.sessionId, isNot(s1));
  });

  test('persisted queue survives a restart', () async {
    final (a, _, prefs) = await _make();
    a.track('kept', {'lat': 4.1234567});
    await Future<void>.delayed(Duration.zero);
    final raw = prefs.getString('analytics.queue')!;
    SharedPreferences.setMockInitialValues({'analytics.queue': raw});
    final prefs2 = await SharedPreferences.getInstance();
    final b = Analytics(prefs: prefs2, transport: _FakeTransport(), cityId: () => 'bogota', autoFlush: false);
    expect(b.pending.single.type, 'kept');
    expect(b.pending.single.props['lat'], 4.123);
  });

  test('no city selected → nothing is sent, nothing lost', () async {
    final (a, t, _) = await _make(city: null);
    a.track('x');
    await a.flush();
    expect(t.batches, isEmpty);
    expect(a.pending.length, 1);
  });

  test('screen names derive from router locations', () {
    expect(screenNameFor('/'), isNull);
    expect(screenNameFor('/cities'), 'cities');
    expect(screenNameFor('/bogota'), 'home');
    expect(screenNameFor('/bogota/plan?from=1'), 'plan');
    expect(screenNameFor('/bogota/itinerary/2'), 'itinerary');
    expect(screenNameFor('/bogota/itinerary/2/go'), 'go');
    expect(screenNameFor('/bogota/routes'), 'routes');
    expect(screenNameFor('/bogota/routes/bogota:12'), 'route');
    expect(screenNameFor('/bogota/stops/bogota:1'), 'stop');
    expect(screenNameFor('/bogota/locate?stop=x'), 'locate');
    expect(screenNameFor('/bogota/settings'), 'settings');
  });
}
