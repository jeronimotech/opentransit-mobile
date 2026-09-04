import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/models/models.dart';

import 'helpers/fixtures.dart';

void main() {
  group('City', () {
    test('parses fixture', () {
      final cities = asList(loadFixture('cities')['cities'], City.fromJson);
      expect(cities.length, 2);
      final bog = cities.first;
      expect(bog.id, 'bogota');
      expect(bog.timezone, 'America/Bogota');
      expect(bog.center.lat, closeTo(4.6534, 1e-6));
      expect(bog.bbox, hasLength(4));
      expect(bog.modes, contains(TravelMode.cableCar));
      expect(bog.primaryColor, '#D32F2F');
      expect(bog.features.realtimeVehicles, isTrue);
      expect(bog.features.fares, isFalse);
      expect(bog.agencies.first.component, Component.trunk);
      expect(bog.contains(const LatLng(4.65, -74.08)), isTrue);
      expect(bog.contains(const LatLng(6.2, -75.5)), isFalse);
    });
  });

  group('PlanResponse', () {
    final plan = PlanResponse.fromJson(loadFixture('plan'));

    test('parses itineraries and legs', () {
      expect(plan.itineraries, hasLength(3));
      final it = plan.itineraries.first;
      expect(it.legs, hasLength(3));
      expect(it.transfers, 0);
      expect(it.legs.first.mode, TravelMode.walk);
      expect(it.legs.first.transit, isFalse);
      expect(it.legs.first.steps, isNotEmpty);
      final bus = it.legs[1];
      expect(bus.mode, TravelMode.bus);
      expect(bus.transit, isTrue);
      expect(bus.route?.shortName, 'B10');
      expect(bus.route?.component, Component.trunk);
      expect(bus.realtime, isTrue);
      expect(bus.realtimeState, RealtimeState.updated);
      expect(bus.delaySeconds, 120);
      expect(bus.intermediateStops, hasLength(6));
      expect(bus.alerts, hasLength(1));
      expect(bus.geometry.encoded, isNotEmpty);
      expect(bus.from.stopId, 'bogota:PN');
      expect(bus.to.stopId, 'bogota:PS');
      expect(it.hasRealtime, isTrue);
      expect(it.alerts, hasLength(1));
    });

    test('times keep their offset', () {
      final it = plan.itineraries.first;
      expect(it.endTime.difference(it.startTime).inSeconds, it.durationSeconds);
      expect(it.startTime.isUtc, isTrue); // parsed from an offset string
    });

    test('request serialises to query params', () {
      final q = PlanRequest(
        from: plan.from,
        to: plan.to,
        arriveBy: true,
        modes: const [TravelMode.bus, TravelMode.walk],
        wheelchair: true,
        numItineraries: 3,
      ).toQuery();
      expect(q['modes'], 'BUS,WALK');
      expect(q['arriveBy'], 'true');
      expect(q['wheelchair'], 'true');
      expect(q['numItineraries'], '3');
      expect(q.containsKey('time'), isFalse);
      expect(double.parse(q['fromLat']!), closeTo(plan.from.position.lat, 1e-9));
    });
  });

  group('Stops & departures', () {
    test('stop detail', () {
      final all = loadFixture('stops');
      final d = StopDetail.fromJson(Map<String, dynamic>.from(all['bogota:PN'] as Map));
      expect(d.stop.name, 'Portal Norte');
      expect(d.stop.isStation, isTrue);
      expect(d.stop.wheelchair, WheelchairAccess.accessible);
      expect(d.routes.map((r) => r.shortName), containsAll(['B10', 'K43']));
    });

    test('nearby stops carry distance', () {
      final stops = asList(loadFixture('stops_nearby')['stops'], Stop.fromJson);
      expect(stops.every((s) => s.distanceMeters != null), isTrue);
    });

    test('departures', () {
      final r = DeparturesResponse.fromJson(loadFixture('departures'));
      expect(r.departures, hasLength(8));
      final live = r.departures.first;
      expect(live.realtime, isTrue);
      expect(live.delaySeconds, 120);
      expect(live.effectiveTime.difference(live.scheduledTime).inSeconds, 120);
      expect(r.departures.where((d) => d.canceled), hasLength(1));
      final sched = r.departures[2];
      expect(sched.realtime, isFalse);
      expect(sched.effectiveTime, sched.scheduledTime);
    });
  });

  group('Routes, network, alerts', () {
    test('route detail with patterns', () {
      final d = RouteDetail.fromJson(
          Map<String, dynamic>.from(loadFixture('route_detail')['bogota:B10'] as Map));
      expect(d.route.shortName, 'B10');
      expect(d.patterns, hasLength(2));
      expect(d.patterns.first.stops.first.name, 'Portal Norte');
      expect(d.patterns.last.directionId, 1);
      expect(d.alerts, hasLength(1));
    });

    test('network shapes', () {
      final shapes = asList(loadFixture('network')['shapes'], NetworkShape.fromJson);
      expect(shapes, isNotEmpty);
      expect(shapes.first.geometry.precision, 5);
    });

    test('alerts', () {
      final alerts = asList(loadFixture('alerts')['alerts'], TransitAlert.fromJson);
      expect(alerts, hasLength(3));
      expect(alerts.map((a) => a.severity), containsAll([AlertSeverity.severe, AlertSeverity.warning, AlertSeverity.info]));
      final a = alerts.first;
      expect(a.routeIds, contains('bogota:B10'));
      expect(a.isActiveAt(a.start!.add(const Duration(days: 1))), isTrue);
      expect(a.isActiveAt(a.end!.add(const Duration(days: 1))), isFalse);
      final open = alerts.last;
      expect(open.end, isNull);
      expect(open.isActiveAt(DateTime.now().add(const Duration(days: 3650))), isTrue);
    });
  });

  group('Vehicles', () {
    test('frame and detail', () {
      final f = VehicleFrame.fromJson(loadFixture('vehicles'));
      expect(f.count, greaterThan(10));
      expect(f.health.pctTripResolved, closeTo(89.1, 0.01));
      final v = f.vehicles.values.first;
      expect(v.routeShortName, isNotNull);
      expect(v.bearing, isNotNull);
      final d = VehicleDetail.fromJson(loadFixture('vehicle_detail'));
      expect(d.route?.shortName, 'B10');
      expect(d.historyPoints, hasLength(10));
      expect(d.nextStop?.name, 'Calle 76');
      expect(d.etaSeconds, 240);
    });
  });

  group('helpers', () {
    test('tolerant parsing', () {
      expect(asInt('12'), 12);
      expect(asInt(12.6), 13);
      expect(asDouble('1.5'), 1.5);
      expect(asBool('true'), isTrue);
      expect(asBool(null), isFalse);
      expect(parseTime('garbage'), isNull);
      expect(Component.parse('trunk'), Component.trunk);
      expect(Component.parse('weird'), Component.other);
      expect(Component.parse(null), isNull);
      expect(TravelMode.parse('CABLE_CAR'), TravelMode.cableCar);
      expect(TravelMode.walk.isTransit, isFalse);
      expect(TravelMode.bus.isTransit, isTrue);
    });
  });
}
