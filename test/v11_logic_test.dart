// Unit tests for the v1.1 pure logic: fares, service windows, board grouping,
// interpolation, version gate, sorting, follow-along, canonical links.
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/live/interpolation.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/utils/eta.dart';
import 'package:opentransit_mobile/core/utils/fare.dart';
import 'package:opentransit_mobile/core/utils/links.dart';
import 'package:opentransit_mobile/core/utils/service_window.dart';
import 'package:opentransit_mobile/core/utils/version.dart';
import 'package:opentransit_mobile/features/planner/follow_along_screen.dart';
import 'package:opentransit_mobile/features/planner/results_screen.dart';

import 'helpers/fixtures.dart';

void main() {
  final plan = PlanResponse.fromJson(loadFixture('plan'));
  final city = City.fromJson(Map<String, dynamic>.from((loadFixture('cities')['cities'] as List).first as Map));

  group('city v1.1 fields', () {
    test('parse components, fares, config, links, services', () {
      expect(city.components.map((c) => c.id), contains(Component.trunk));
      expect(city.componentStyle(Component.cable)?.label, 'TransMiCable');
      expect(city.fares?.base, 3200);
      expect(city.config.departuresRefreshSeconds, 20);
      expect(city.config.isEnabled('board'), isTrue);
      expect(city.config.isEnabled('not-a-flag'), isTrue, reason: 'unknown flags default to enabled');
      expect(city.links.pqrs, isNotNull);
      expect(city.services.map((s) => s.id), contains('recharge'));
      expect(city.config.maintenance.active, isFalse);
    });

    test('missing config degrades to defaults', () {
      final c = City.fromJson({'id': 'x', 'name': 'X'});
      expect(c.fares, isNull);
      expect(c.config.vehiclePollSeconds, 15);
      expect(c.services, isEmpty);
      expect(c.componentStyle(Component.trunk), isNull);
    });
  });

  group('fare', () {
    test('uses the API fare when present', () {
      final f = fareFor(plan.itineraries.first, city)!;
      expect(f.amount, 3200);
      expect(f.estimated, isTrue);
    });

    test('estimates from city parameters: base + free transfer within window', () {
      final it = plan.itineraries[1]; // K43 then G12, second boards ~38 min later
      final stripped = Itinerary(
        id: it.id, startTime: it.startTime, endTime: it.endTime, durationSeconds: it.durationSeconds,
        walkDistanceMeters: it.walkDistanceMeters, walkTimeSeconds: it.walkTimeSeconds,
        waitingTimeSeconds: it.waitingTimeSeconds, transfers: it.transfers, legs: it.legs,
      );
      final f = estimateFare(stripped, city.fares)!;
      expect(f.amount, 3200);
      expect(f.breakdown.map((l) => l.label), ['base', 'transfer']);
    });

    test('charges a second base fare outside the transfer window', () {
      final it = plan.itineraries[1];
      final late = CityFares(currency: 'COP', base: 3200, transfer: 0, transferWindowMinutes: 10);
      final stripped = Itinerary(
        id: it.id, startTime: it.startTime, endTime: it.endTime, durationSeconds: it.durationSeconds,
        walkDistanceMeters: it.walkDistanceMeters, walkTimeSeconds: it.walkTimeSeconds,
        waitingTimeSeconds: it.waitingTimeSeconds, transfers: it.transfers, legs: it.legs,
      );
      expect(estimateFare(stripped, late)!.amount, 6400);
    });

    test('walk-only itineraries and cities without fares give null', () {
      final walkOnly = Itinerary(
        id: 'w', startTime: DateTime.now(), endTime: DateTime.now(), durationSeconds: 1,
        walkDistanceMeters: 1, walkTimeSeconds: 1, waitingTimeSeconds: 0, transfers: 0,
        legs: [plan.itineraries.first.legs.first],
      );
      expect(estimateFare(walkOnly, city.fares), isNull);
      expect(estimateFare(plan.itineraries.first, null), isNull);
    });

    test('formats COP without decimals', () {
      expect(formatMoney(3200, 'COP', 'es'), r'$ 3.200');
      expect(formatMoney(2.5, 'USD', 'en'), r'US$ 2.50');
    });
  });

  group('service window', () {
    test('status and hints', () {
      const active = ServiceWindow(start: '04:00', end: '23:00', active: true);
      const later = ServiceWindow(start: '05:00', end: '09:00', active: false, nextStart: '14:00');
      const done = ServiceWindow(start: '05:00', end: '09:00', active: false);
      String hint(ServiceWindow? w) =>
          serviceHint(w, outOfHours: 'Fuera de horario', nextAt: (t) => 'próximo $t', noMoreToday: 'Sin servicio hoy') ?? 'none';
      expect(serviceStatus(active), ServiceStatus.active);
      expect(hint(active), 'none');
      expect(hint(later), 'Fuera de horario · próximo 14:00');
      expect(hint(done), 'Sin servicio hoy');
      expect(hint(null), 'none');
      expect(serviceSpan(active), '04:00 – 23:00');
    });

    test('RouteRef parses serviceWindow', () {
      final routes = asList(loadFixture('routes')['routes'], RouteRef.fromJson);
      final cable = routes.firstWhere((r) => r.shortName == 'L10');
      expect(cable.serviceWindow?.active, isFalse);
      expect(cable.serviceWindow?.nextStart, '14:00');
    });
  });

  group('board', () {
    test('parses the API board', () {
      final b = BoardResponse.fromJson(loadFixture('board'));
      expect(b.rows, hasLength(3));
      expect(b.rows.first.route.shortName, 'B10');
      expect(b.rows.first.next.first.realtime, isTrue);
      expect(b.freshness.stale, isFalse);
    });

    test('groups a flat departures list by route+headsign, capped per route, sorted by first time', () {
      final now = DateTime.parse('2026-09-04T08:00:00-05:00');
      final d = DeparturesResponse.fromJson(loadFixture('departures'));
      final b = BoardResponse.fromDepartures(d, perRoute: 2, now: now);
      expect(b.rows.map((r) => r.route.shortName), ['B10', 'K43', 'B74']);
      expect(b.rows.every((r) => r.next.length <= 2), isTrue);
      expect(b.rows.first.next.first.minutes, 5, reason: '08:03 + 2 min delay → 08:05');
      // the cancelled K43 at 08:17 is skipped
      expect(b.rows[1].next.map((t) => t.tripId), isNot(contains('bogota:K43-0817')));
      expect(b.freshness.realtime, isTrue);
    });
  });

  group('next buses', () {
    test('parses sources and vehicles', () {
      final n = NextBusesResponse.fromJson(loadFixture('next'));
      expect(n.next.map((x) => x.source), ['live', 'estimated', 'scheduled']);
      expect(n.next.first.vehicle, isNotNull);
      expect(n.next.first.stopsAway, 2);
      expect(n.next.last.vehicle, isNull);
    });

    test('eta buckets', () {
      expect(etaBucket(3), EtaBucket.imminent);
      expect(etaBucket(8), EtaBucket.soon);
      expect(etaBucket(15), EtaBucket.later);
      expect(etaBucket(40), EtaBucket.far);
      expect(etaBucket(null), EtaBucket.unknown);
    });
  });

  group('pois', () {
    test('parses a GeoJSON collection', () {
      final pois = Poi.fromCollection(loadFixture('pois'));
      expect(pois, hasLength(10));
      expect(pois.first.type, 'bike_parking');
      expect(pois.first.position.lat, closeTo(4.7552, 1e-6));
    });
  });

  group('dominant component', () {
    test('picks the most frequent route component, null when unknown', () {
      final routes = asList(loadFixture('routes')['routes'], RouteRef.fromJson);
      expect(dominantComponent(routes), Component.trunk);
      expect(dominantComponent(const []), isNull);
      final s = const Stop(id: 'x', name: 'x', position: LatLng(0, 0), locationType: 'station');
      expect(s.withComponent(Component.zonal).component, Component.zonal);
    });
  });

  group('accessibility', () {
    test('explicit block is used, legacy field is unverified', () {
      final stops = loadFixture('stops');
      final pn = Stop.fromJson(Map<String, dynamic>.from(stops['bogota:PN'] as Map));
      expect(pn.access.verified, isFalse);
      expect(pn.access.source, 'gtfs');
      final legacy = Stop.fromJson({'id': 'x', 'name': 'x', 'lat': 0, 'lon': 0, 'wheelchair': 'accessible'});
      expect(legacy.access.wheelchair, WheelchairAccess.accessible);
      expect(legacy.access.verified, isFalse);
    });
  });

  group('interpolation', () {
    test('eases from the shown position to the new one and snaps on big jumps', () {
      final interp = VehicleInterpolator(duration: const Duration(seconds: 10));
      final t0 = DateTime(2026, 1, 1, 12);
      VehicleFrame frame(int seq, double lat) => VehicleFrame(
            seq: seq, generatedAt: t0, health: const VehicleHealth(),
            vehicles: {'v': Vehicle(id: 'v', position: LatLng(lat, -74))},
          );
      expect(interp.ingest(frame(1, 4.0), t0), isTrue);
      expect(interp.ingest(frame(1, 4.0), t0), isFalse, reason: 'same seq is ignored');
      expect(interp.positionAt('v', t0)!.lat, 4.0);
      // 0.001° ≈ 111 m → animates
      interp.ingest(frame(2, 4.001), t0);
      expect(interp.isAnimating(t0), isTrue);
      final mid = interp.positionAt('v', t0.add(const Duration(seconds: 5)))!.lat;
      expect(mid, greaterThan(4.0));
      expect(mid, lessThan(4.001));
      expect(interp.positionAt('v', t0.add(const Duration(seconds: 11)))!.lat, 4.001);
      expect(interp.isAnimating(t0.add(const Duration(seconds: 11))), isFalse);
      // 0.1° ≈ 11 km → snap
      interp.ingest(frame(3, 4.101), t0.add(const Duration(seconds: 12)));
      expect(interp.positionAt('v', t0.add(const Duration(seconds: 12)))!.lat, 4.101);
      expect(interp.isAnimating(t0.add(const Duration(seconds: 12))), isFalse);
    });

    test('drops vehicles missing from the new frame', () {
      final interp = VehicleInterpolator();
      final t0 = DateTime(2026);
      interp.ingest(VehicleFrame(seq: 1, generatedAt: t0, health: const VehicleHealth(), vehicles: {
        'a': const Vehicle(id: 'a', position: LatLng(1, 1)),
        'b': const Vehicle(id: 'b', position: LatLng(2, 2)),
      }), t0);
      interp.ingest(VehicleFrame(seq: 2, generatedAt: t0, health: const VehicleHealth(), vehicles: {
        'a': const Vehicle(id: 'a', position: LatLng(1, 1)),
      }), t0);
      expect(interp.trackedCount, 1);
      expect(interp.positionAt('b', t0), isNull);
    });
  });

  group('version gate', () {
    test('compares dotted versions', () {
      expect(compareVersions('1.2.3', '1.2.3'), 0);
      expect(compareVersions('1.2', '1.2.0'), 0);
      expect(compareVersions('0.9.9', '1.0.0'), lessThan(0));
      expect(compareVersions('1.10.0+5', '1.9.9'), greaterThan(0));
      expect(needsUpdate('1.0.0', '1.1.0'), isTrue);
      expect(needsUpdate('1.0.0', '1.0.0'), isFalse);
      expect(needsUpdate('0.2.0', null), isFalse);
      expect(needsUpdate('0.2.0', ''), isFalse);
    });
  });

  group('sorting', () {
    test('each chip orders as expected and keeps router order on ties', () {
      final its = plan.itineraries; // durations 3860, 4100, 5300; transfers 0,1,1
      expect(sortItineraries(its, ItinerarySort.fastest).map((i) => i.id), ['it-0', 'it-1', 'it-2']);
      expect(sortItineraries(its, ItinerarySort.fewerTransfers).map((i) => i.id), ['it-0', 'it-1', 'it-2']);
      final byWalk = sortItineraries(its, ItinerarySort.lessWalking);
      expect(byWalk.first.walkDistanceMeters, its.map((i) => i.walkDistanceMeters).reduce((a, b) => a < b ? a : b));
      expect(sortItineraries(its, ItinerarySort.earliest).map((i) => i.id), ['it-0', 'it-1', 'it-2']);
      expect(sortItineraries(its, ItinerarySort.cheapest, city: city).map((i) => i.id), ['it-0', 'it-1', 'it-2']);
    });
  });

  group('waiting for the bus', () {
    // A tester standing at the stop was told "Bájate en Compensar CUR · 4.9 km a tu parada": the
    // instruction for the ride, and the distance to the stop where he gets *off*, while what he
    // needed was when his bus arrives. The leg advances to the bus the moment the walk ends, so the
    // screen has to tell the two phases apart on its own.
    test('you are waiting until you are well clear of the boarding stop', () {
      final it = plan.itineraries.first; // walk → B10 → walk
      final bus = it.legs[1];
      final stop = bus.from.position;
      expect(boardedTransitLeg(bus, stop, wasBoarded: false), isFalse, reason: 'standing at the stop');
      expect(boardedTransitLeg(bus, _metersNorth(stop, 100), wasBoarded: false), isFalse,
          reason: 'GPS wander at the kerb is not boarding');
      expect(boardedTransitLeg(bus, _metersNorth(stop, 300), wasBoarded: false), isTrue,
          reason: 'well clear of the stop → on board');
    });

    test('does not flip back and forth while you stand still', () {
      final bus = plan.itineraries.first.legs[1];
      final stop = bus.from.position;
      // once boarded it takes coming back to the stop to be waiting again, not just drifting near it
      expect(boardedTransitLeg(bus, _metersNorth(stop, 200), wasBoarded: true), isTrue);
      expect(boardedTransitLeg(bus, _metersNorth(stop, 60), wasBoarded: true), isFalse);
    });

    test('a leg you cannot board is never "waiting"', () {
      final walk = plan.itineraries.first.legs[0];
      expect(walk.transit, isFalse);
      expect(boardedTransitLeg(walk, walk.from.position, wasBoarded: false), isTrue);
      // no fix yet: keep whatever we knew rather than guessing
      expect(boardedTransitLeg(plan.itineraries.first.legs[1], null, wasBoarded: true), isTrue);
      expect(boardedTransitLeg(plan.itineraries.first.legs[1], null, wasBoarded: false), isFalse);
    });
  });

  group('live eta', () {
    // A tester 1 km from his stop at 7:30 was still shown 7:59: the arrival the router predicted
    // before he set off, which never moved for the whole trip. He got there around 7:35.
    test('re-estimates from where you are, instead of repeating the plan', () {
      final it = plan.itineraries.first; // walk → B10 → walk
      final now = DateTime.parse('2026-09-04T07:30:00-05:00');
      final bus = it.legs[1];

      // most of the bus leg still to go: close to the plan's own remaining time
      final far = liveEta(it, legIndex: 1, metersToLegEnd: bus.distanceMeters.toDouble(), now: now);
      expect(far.difference(now).inSeconds,
          bus.durationSeconds + it.legs[2].durationSeconds);

      // almost there: the estimate has to come down with the distance, which endTime never did
      final near = liveEta(it, legIndex: 1, metersToLegEnd: bus.distanceMeters * 0.1, now: now);
      expect(near.isBefore(far), isTrue);
      expect(near.difference(now).inSeconds,
          lessThan(bus.durationSeconds + it.legs[2].durationSeconds));

      // and the legs still ahead are still counted: it is not just "this leg"
      expect(near.difference(now).inSeconds, greaterThanOrEqualTo(it.legs[2].durationSeconds));
    });

    test('before the first fix it falls back to the plan, not to zero', () {
      final it = plan.itineraries.first;
      final now = DateTime.parse('2026-09-04T07:30:00-05:00');
      final planned = it.legs[1].durationSeconds + it.legs[2].durationSeconds;
      expect(liveEta(it, legIndex: 1, metersToLegEnd: null, now: now).difference(now).inSeconds, planned);
    });

    test('on the last leg, at its end, the answer is now', () {
      final it = plan.itineraries.first;
      final now = DateTime.parse('2026-09-04T07:30:00-05:00');
      expect(liveEta(it, legIndex: it.legs.length - 1, metersToLegEnd: 0, now: now), now);
      // an out-of-range index is clamped rather than thrown
      expect(liveEta(it, legIndex: 99, metersToLegEnd: 0, now: now), now);
    });
  });

  group('follow along', () {
    test('advances legs as their ends are reached and detects arrival', () {
      final it = plan.itineraries.first; // walk → B10 → walk
      final start = it.legs.first.from.position;
      var st = followAlongStep(it, start);
      expect(st.legIndex, 0);
      st = followAlongStep(it, it.legs[0].to.position, previous: 0);
      expect(st.legIndex, 1, reason: 'reached the boarding stop → on the bus leg');
      st = followAlongStep(it, it.legs[1].to.position, previous: 1);
      expect(st.legIndex, 2);
      st = followAlongStep(it, it.legs[2].to.position, previous: 2);
      expect(st.arrived, isTrue);
      // never goes backwards
      st = followAlongStep(it, start, previous: 2);
      expect(st.legIndex, 2);
    });
  });

  group('canonical links', () {
    test('builds https URLs and maps them (and the custom scheme) back', () {
      final u = CanonicalLinks.stop('bogota', 'bogota:2000');
      expect(u.scheme, 'https');
      expect(u.path, '/bogota/stops/bogota:2000');
      expect(CanonicalLinks.toAppLocation(u), '/bogota/stops/bogota:2000');
      expect(CanonicalLinks.toAppLocation(Uri.parse('opentransit://bogota/plan?toLat=1')), '/bogota/plan?toLat=1');
      expect(CanonicalLinks.toAppLocation(Uri.parse('https://example.com/x')), isNull);
      final l = CanonicalLinks.locate('bogota', stopId: 's1');
      expect(l.queryParameters, {'stop': 's1'});
    });
  });
}

/// A point [meters] due north of [p], for thresholds that are about distance and not direction.
LatLng _metersNorth(LatLng p, double meters) => LatLng(p.lat + meters / 111320.0, p.lon);
