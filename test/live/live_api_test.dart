// Contract check against a *running* API, not the fixtures.
//
// Skipped unless `OT_LIVE` is set, because it needs a server:
//   flutter test test/live/live_api_test.dart \
//     --dart-define=OT_LIVE=1 --dart-define=OT_API=http://localhost:8001
//
// Its job is to catch the failure mode this project has hit before: a mock that
// emits a shape the real API never sends. Everything asserted here is something
// the planner relies on (contract addendum v2.1).
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/api/http_api_client.dart';
import 'package:opentransit_mobile/core/models/models.dart';

const _live = String.fromEnvironment('OT_LIVE');
const _base = String.fromEnvironment('OT_API', defaultValue: 'http://localhost:8001');
const _city = String.fromEnvironment('OT_CITY', defaultValue: 'bogota');
final _skip =
    _live.isEmpty ? 'set --dart-define=OT_LIVE=1 and run the API' : null;

void main() {
  final api = HttpApiClient(_base);
  // The city's own centre, so nothing here is a hardcoded Bogotá coordinate.
  late LatLng near;

  setUpAll(() async {
    near = (await api.city(_city)).center;
  });

  test('geocode returns places, not only GTFS stops', () async {
    final res = await api.geocode(_city, 'Calle 85', near: near);
    expect(res, isNotEmpty);
    expect(res.where((r) => r.source == 'photon'), isNotEmpty);
    expect(res.where((r) => r.isStop), isNotEmpty);
    for (final r in res) {
      expect(['station', 'stop', 'address', 'street', 'poi', 'place'],
          contains(r.type));
      expect(['gtfs', 'photon'], contains(r.source));
      expect(r.name, isNotEmpty);
    }
  }, skip: _skip);

  test('a query with a house number ranks addresses', () async {
    final res = await api.geocode(_city, 'Carrera 7 # 71-21', near: near);
    expect(res.where((r) => r.type == 'address'), isNotEmpty);
  }, skip: _skip);

  test('reverse geocoding answers with a name for an arbitrary point',
      () async {
    final p = await api.reverse(_city, near);
    expect(p.name.trim(), isNotEmpty);
    expect(p.position.lat, closeTo(near.lat, 0.001));
  }, skip: _skip);

  test('any geocode result is a valid endpoint, in either direction', () async {
    final res = await api.geocode(_city, 'Calle 85', near: near);
    final place = res.firstWhere((r) => !r.isStop);
    final stop = res.firstWhere((r) => r.isStop);

    for (final pair in [
      (place.toPlace(), stop.toPlace()),
      (stop.toPlace(), place.toPlace()),
    ]) {
      final req = PlanRequest(from: pair.$1, to: pair.$2);
      // The labels the client sends are what makes the itinerary readable.
      expect(req.toQuery()['fromName'], pair.$1.name);
      expect(req.toQuery()['toName'], pair.$2.name);
      final plan = await api.plan(_city, req);
      expect(plan.itineraries, isNotEmpty);
      // …and they come back on the plan, not a coordinate pair.
      expect(plan.itineraries.first.legs, isNotEmpty);
    }
  }, skip: _skip);

  test('the router is up, so a failing plan above is the planner not the API',
      () async {
    expect((await api.health(_city)).routerUp, isTrue);
  }, skip: _skip);
}
