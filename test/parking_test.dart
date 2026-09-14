import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/api/mock_api_client.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/utils/scenarios.dart';

import 'helpers/fixtures.dart';

Leg _leg({required bool transit, required DateTime start, required int minutes, TravelMode? mode, bool parkRide = false}) {
  final end = start.add(Duration(minutes: minutes));
  return Leg(
    mode: mode ?? (transit ? TravelMode.bus : TravelMode.walk),
    transit: transit,
    startTime: start,
    endTime: end,
    durationSeconds: minutes * 60,
    distanceMeters: minutes * 80,
    from: Place(name: 'A', position: const LatLng(4.6, -74.1), departure: start),
    to: Place(name: 'B', position: const LatLng(4.61, -74.11), arrival: end),
    realtime: false,
    geometry: const Geometry(encoded: ''),
    parkRide: parkRide,
  );
}

Itinerary _it(String id, DateTime start, List<Leg> legs, {String? source, ParkingInfo? parking}) {
  final end = legs.last.endTime;
  return Itinerary(
    id: id,
    startTime: start,
    endTime: end,
    durationSeconds: end.difference(start).inSeconds,
    walkDistanceMeters: 300,
    walkTimeSeconds: 230,
    waitingTimeSeconds: 0,
    transfers: 0,
    legs: legs,
    modesUsed: [for (final l in legs) l.mode.wire],
    source: source,
    parking: parking,
  );
}

void main() {
  final now = DateTime(2026, 9, 14, 10, 0);

  group('parking models (v1.6)', () {
    test('CurbZone parses the public curb shape', () {
      final z = CurbZone.fromJson({
        'id': 'z1', 'name': 'Und1191', 'streetName': 'KR 54CL 57BCL 58',
        'center': {'lat': 4.6595, 'lon': -74.07885},
        'availableSpaces': 4, 'totalSpaces': 8, 'occupied': 4, 'occupancyRate': 0.5,
        'available': true, 'availabilityTime': '2026-09-14T16:48:44+00:00',
        'priceLabel': r'$ 9.000 / hora', 'allowed': true, 'nextChange': '2026-09-14T22:00:00-05:00',
      });
      expect(z.title, 'Und1191');
      expect(z.position.lat, closeTo(4.6595, 1e-6));
      expect(z.availableSpaces, 4);
      expect(z.totalSpaces, 8);
      expect(z.tone, ParkingTone.ok);
      expect(z.ageSeconds(now: DateTime.utc(2026, 9, 14, 17, 48, 44)), 3600);
      expect(z.nextChange, isNotNull);
    });

    test('CurbZone without a count still has a title and an unknown tone', () {
      final z = CurbZone.fromJson({'id': 'z2', 'streetName': 'CL 57B', 'center': {'lat': 4.658, 'lon': -74.077}, 'totalSpaces': 15});
      expect(z.title, 'CL 57B');
      expect(z.availableSpaces, isNull);
      expect(z.ageSeconds(), isNull);
      expect(z.tone, ParkingTone.unknown);
    });

    test('parkingTone: closed beats everything, then full / low / ok', () {
      expect(parkingTone(available: 5, total: 10, allowed: false), ParkingTone.closed);
      expect(parkingTone(available: 0, total: 10, allowed: true), ParkingTone.full);
      expect(parkingTone(available: 1, total: 10, allowed: true), ParkingTone.low);
      expect(parkingTone(available: 8, total: 10, allowed: true), ParkingTone.ok);
      expect(parkingTone(available: null, total: 10, allowed: true), ParkingTone.unknown);
    });

    test('ParkingInfo parses fee, walk and legality window', () {
      final p = ParkingInfo.fromJson({
        'curbZoneId': 'z1', 'name': 'Und1414', 'streetName': 'KR 7', 'position': {'lat': 4.7, 'lon': -74.03},
        'availableSpaces': 29, 'totalSpaces': 44, 'availabilityTime': '2026-09-14T14:00:00+00:00',
        'priceLabel': r'$ 6.300 / hora', 'allowedUntil': '2026-09-14T22:00:00-05:00',
        'fee': {'amount': 70200, 'currency': 'COP', 'dwellHours': 8},
        'walkMeters': 138, 'walkSeconds': 115,
      });
      expect(p.title, 'Und1414');
      expect(p.fee?.amount, 70200);
      expect(p.fee?.dwellHours, 8);
      expect(p.walkMeters, 138);
      expect(p.allowedUntil, isNotNull);
      expect(p.tone, ParkingTone.ok);
    });
  });

  group('plan (v1.6)', () {
    test('Leg.parkRide and Itinerary.parking survive fromJson and copyWith', () {
      final it = Itinerary.fromJson({
        'id': 'p1', 'startTime': '2026-09-14T10:00:00-05:00', 'endTime': '2026-09-14T11:00:00-05:00',
        'durationSeconds': 3600, 'walkDistanceMeters': 138, 'walkTimeSeconds': 115, 'waitingTimeSeconds': 0, 'transfers': 0,
        'modesUsed': ['CAR', 'WALK', 'BUS'], 'source': 'parkride',
        'parking': {'curbZoneId': 'z', 'name': 'Und1414', 'position': {'lat': 4.7, 'lon': -74.03}, 'walkMeters': 138, 'walkSeconds': 115},
        'legs': [
          {
            'mode': 'CAR', 'transit': false, 'parkRide': true,
            'startTime': '2026-09-14T10:00:00-05:00', 'endTime': '2026-09-14T10:20:00-05:00',
            'durationSeconds': 1200, 'distanceMeters': 9000, 'realtime': false, 'geometry': {'encoded': ''},
            'from': {'name': 'Casa', 'position': {'lat': 4.74, 'lon': -74.09}},
            'to': {'name': 'Und1414', 'position': {'lat': 4.7, 'lon': -74.03}},
          },
        ],
      });
      expect(it.hasParkRide, isTrue);
      expect(it.legs.single.parkRide, isTrue);
      expect(it.legs.single.copyWith().parkRide, isTrue);
      expect(it.copyWith().parking?.title, 'Und1414');
      expect(it.parking?.walkMeters, 138);
    });

    test('a plain itinerary is not park & ride', () {
      final it = _it('a', now, [_leg(transit: true, start: now, minutes: 20)]);
      expect(it.hasParkRide, isFalse);
      expect(it.hasOnDemand, isFalse);
    });

    test('PlanRequest sends parkAndRide=true only when asked', () {
      final from = Place(name: 'Casa', position: const LatLng(4.74, -74.09));
      final to = Place(name: 'Trabajo', position: const LatLng(4.60, -74.07));
      expect(PlanRequest(from: from, to: to).toQuery().containsKey('parkAndRide'), isFalse);
      expect(PlanRequest(from: from, to: to, parkAndRide: true).toQuery()['parkAndRide'], 'true');
    });

    test('FareLine.isParking', () {
      expect(FareLine.fromJson({'label': 'Parqueo · Und1414 (8 h)', 'amount': 70200, 'kind': 'parking'}).isParking, isTrue);
      expect(FareLine.fromJson({'label': 'Bus', 'amount': 3200}).isParking, isFalse);
    });

    test('groupByScenario puts park & ride in its own group, never with taxi or the pool', () {
      final transit = _it('t', now, [_leg(transit: true, start: now, minutes: 40)]);
      final car = _leg(transit: false, start: now, minutes: 15, mode: TravelMode.car, parkRide: true);
      final pr = _it('p', now, [car, _leg(transit: true, start: now.add(const Duration(minutes: 18)), minutes: 25)],
          source: 'parkride', parking: ParkingInfo(curbZoneId: 'z', name: 'Und1414', position: const LatLng(4.7, -74.03), walkMeters: 100, walkSeconds: 80));
      final groups = groupByScenario([transit, pr]);
      expect(groups.map((g) => g.scenario), contains(Scenario.parkRide));
      expect(groups.firstWhere((g) => g.scenario == Scenario.parkRide).best.id, 'p');
      expect(groups.where((g) => g.scenario == Scenario.onDemand), isEmpty);
      expect(groups.firstWhere((g) => g.scenario == Scenario.fastest).best.id, 't');
    });
  });

  group('city (v1.6)', () {
    test('curbs and park & ride only where the city says so', () {
      final on = City.fromJson({
        'id': 'bogota', 'name': 'Bogotá', 'config': {},
        'openMobility': {'cds': {'enabled': true}, 'parkRide': {'enabled': true, 'maxWalkMeters': 600, 'defaultDwellHours': 8}},
      });
      final noPr = City.fromJson({'id': 'x', 'name': 'X', 'config': {}, 'openMobility': {'cds': {'enabled': true}}});
      final off = City.fromJson({'id': 'y', 'name': 'Y', 'config': {}});
      final killed = City.fromJson({
        'id': 'z', 'name': 'Z', 'config': {'features': {'parkRide': false}},
        'openMobility': {'cds': {'enabled': true}, 'parkRide': {'enabled': true}},
      });
      expect(on.curbsEnabled, isTrue);
      expect(on.parkRideEnabled, isTrue);
      expect(on.openMobility.maxWalkMeters, 600);
      expect(noPr.curbsEnabled, isTrue);
      expect(noPr.parkRideEnabled, isFalse);
      expect(off.curbsEnabled, isFalse);
      expect(killed.curbsEnabled, isTrue);
      expect(killed.parkRideEnabled, isFalse);
    });
  });

  group('mock curbs', () {
    final api = MockApiClient(bundle: DiskAssetBundle(), now: now, latency: Duration.zero);

    test('returns the fixture zones for Bogotá, filtered by bbox', () async {
      final all = await api.curbs('bogota');
      expect(all.length, 3);
      expect(all.map((z) => z.tone).toSet(), {ParkingTone.ok, ParkingTone.full, ParkingTone.closed});
      final some = await api.curbs('bogota', bbox: [-74.0795, 4.659, -74.078, 4.66]);
      expect(some.map((z) => z.name), ['Und1191']);
    });

    test('is empty where the city publishes none', () async {
      expect(await api.curbs('medellin'), isEmpty);
    });
  });
}
