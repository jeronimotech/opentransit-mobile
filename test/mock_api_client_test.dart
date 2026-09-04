import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/api/api_client.dart';
import 'package:opentransit_mobile/core/api/mock_api_client.dart';
import 'package:opentransit_mobile/core/models/models.dart';

import 'helpers/fixtures.dart';

void main() {
  final now = DateTime.parse('2026-10-10T15:30:00-05:00');
  MockApiClient client() => MockApiClient(bundle: DiskAssetBundle(), now: now, latency: Duration.zero);

  test('rebaseTimes shifts every ISO timestamp and nothing else', () {
    final shifted = MockApiClient.rebaseTimes(
      {'a': '2026-09-04T08:00:00-05:00', 'b': 'hello', 'c': 5, 'd': ['2026-09-04T09:00:00-05:00']},
      const Duration(hours: 1),
    ) as Map;
    expect(DateTime.parse(shifted['a'] as String).toUtc(), DateTime.parse('2026-09-04T09:00:00-05:00').toUtc());
    expect(shifted['b'], 'hello');
    expect(shifted['c'], 5);
    expect(DateTime.parse((shifted['d'] as List).first as String).toUtc(), DateTime.parse('2026-09-04T10:00:00-05:00').toUtc());
  });

  test('cities and city lookup', () async {
    final c = client();
    expect((await c.cities()).map((x) => x.id), ['bogota', 'medellin']);
    expect((await c.city('bogota')).name, 'Bogotá');
    expect(() => c.city('nope'), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'CITY_NOT_FOUND')));
  });

  test('plan anchors the first itinerary at the requested time', () async {
    final c = client();
    final from = const Place(name: 'A', position: LatLng(4.7546, -74.0459));
    final to = const Place(name: 'B', position: LatLng(4.5978, -74.1616));
    final when = now.add(const Duration(hours: 2));
    final res = await c.plan('bogota', PlanRequest(from: from, to: to, time: when));
    expect(res.itineraries, hasLength(3));
    expect(res.itineraries.first.startTime.toUtc(), when.toUtc());
    expect(res.from.name, 'A');
    expect(res.itineraries.first.legs[1].route?.shortName, 'B10');

    final wheel = await c.plan('bogota', PlanRequest(from: from, to: to, wheelchair: true));
    expect(wheel.itineraries.every((i) => i.accessible == true), isTrue);

    final walkOnly = await c.plan('bogota', PlanRequest(from: from, to: to, modes: const [TravelMode.walk]));
    expect(walkOnly.itineraries, isEmpty);
    expect(walkOnly.warnings, contains('NO_ITINERARIES'));
  });

  test('geocode is accent-insensitive and prefix-ranked', () async {
    final c = client();
    final r = await c.geocode('bogota', 'portal');
    expect(r.first.name, startsWith('Portal'));
    expect(r.every((x) => x.name.toLowerCase().contains('portal')), isTrue);
    final j = await c.geocode('bogota', 'jimenez');
    expect(j.first.name, 'Av. Jiménez');
    expect(await c.geocode('bogota', 'zzzz'), isEmpty);
  });

  test('nearby stops are sorted by distance and never empty', () async {
    final c = client();
    final near = await c.nearbyStops('bogota', const LatLng(4.7546, -74.0459), radiusMeters: 800);
    expect(near.first.name, 'Portal Norte');
    expect(near.first.distanceMeters, lessThan(50));
    for (var i = 1; i < near.length; i++) {
      expect(near[i].distanceMeters!, greaterThanOrEqualTo(near[i - 1].distanceMeters!));
    }
    final far = await c.nearbyStops('bogota', const LatLng(4.0, -74.5), radiusMeters: 100);
    expect(far, hasLength(5)); // graceful fallback to the 5 closest
  });

  test('departures are re-anchored to now and bounded', () async {
    final c = client();
    final r = await c.departures('bogota', 'bogota:PN', minutes: 15);
    expect(r.stop.name, 'Portal Norte');
    expect(r.departures, isNotEmpty);
    expect(r.departures.first.effectiveTime.isAfter(now), isTrue);
    expect(r.departures.every((d) => d.effectiveTime.isBefore(now.add(const Duration(minutes: 15)))), isTrue);
    expect(() => c.stop('bogota', 'nope'), throwsA(isA<ApiException>()));
  });

  test('routes filter by component and query; detail and network', () async {
    final c = client();
    expect((await c.routes('bogota', component: Component.cable)).single.shortName, 'L10');
    expect((await c.routes('bogota', query: 'ricaurte')).map((r) => r.shortName), containsAll(['K43', 'G12']));
    final d = await c.route('bogota', 'bogota:B10');
    expect(d.patterns, hasLength(2));
    expect((await c.network('bogota')), isNotEmpty);
  });

  test('vehicles snapshot, detail, alerts', () async {
    final c = client();
    final f = await c.vehicles('bogota');
    expect(f.count, greaterThan(10));
    final only = await c.vehicles('bogota', routeId: 'bogota:B10');
    expect(only.vehicles.values.every((v) => v.routeId == 'bogota:B10'), isTrue);
    final d = await c.vehicle('bogota', f.vehicles.keys.first);
    expect(d.route, isNotNull);
    final alerts = await c.alerts('bogota');
    expect(alerts.length, greaterThanOrEqualTo(2));
    expect(await c.alerts('bogota', routeId: 'bogota:B10'), hasLength(1));
  });

  test('stream emits a full frame then deltas that move vehicles', () async {
    final c = client();
    final events = await c.vehicleEvents('bogota').take(2).toList();
    expect(events.first['type'], 'full');
    expect(events.last['type'], 'delta');
    expect((events.last['updated'] as List), isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 20)));
}
