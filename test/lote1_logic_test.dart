import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/utils/countdown.dart';
import 'package:opentransit_mobile/core/utils/retime.dart';
import 'package:opentransit_mobile/core/utils/scenarios.dart';
import 'package:opentransit_mobile/features/planner/itinerary_detail_screen.dart' show showDeparturesFor;

Leg _leg({
  required bool transit,
  required DateTime start,
  required int minutes,
  String? routeId,
  TravelMode? mode,
  LegRental? rental,
  LegOnDemand? onDemand,
  String? stopId,
}) {
  final end = start.add(Duration(minutes: minutes));
  return Leg(
    mode: mode ?? (transit ? TravelMode.bus : TravelMode.walk),
    transit: transit,
    startTime: start,
    endTime: end,
    durationSeconds: minutes * 60,
    distanceMeters: minutes * 80,
    from: Place(name: 'A', position: const LatLng(4.6, -74.1), stopId: stopId, departure: start),
    to: Place(name: 'B', position: const LatLng(4.61, -74.11), arrival: end),
    route: routeId == null
        ? null
        : RouteRef(id: routeId, shortName: routeId, longName: routeId, color: '#D32F2F', textColor: '#FFFFFF', mode: TravelMode.bus, agencyId: '1'),
    realtime: false,
    geometry: const Geometry(encoded: ''),
    intermediateStops: [Place(name: 'M', position: const LatLng(4.605, -74.105), arrival: start.add(Duration(minutes: minutes ~/ 2)))],
    rental: rental,
    onDemand: onDemand,
  );
}

Itinerary _it(String id, DateTime start, List<Leg> legs, {int walk = 500, int transfers = 0, num? fare}) {
  final end = legs.last.endTime;
  return Itinerary(
    id: id,
    startTime: start,
    endTime: end,
    durationSeconds: end.difference(start).inSeconds,
    walkDistanceMeters: walk,
    walkTimeSeconds: walk ~/ 1.3,
    waitingTimeSeconds: 0,
    transfers: transfers,
    fare: fare == null ? null : Fare(amount: fare, currency: 'COP'),
    legs: legs,
    modesUsed: [for (final l in legs) l.mode.wire],
  );
}

void main() {
  final now = DateTime(2026, 9, 6, 10, 0);

  group('leave-by countdown', () {
    test('minutes ahead, now, departed', () {
      expect(leaveState(now.add(const Duration(minutes: 4, seconds: 20)), now), const LeaveState(LeaveKind.leaveIn, 4));
      expect(leaveState(now.add(const Duration(seconds: 61)), now), const LeaveState(LeaveKind.leaveIn, 1));
      expect(leaveState(now.add(const Duration(seconds: 30)), now).kind, LeaveKind.leaveNow);
      expect(leaveState(now.subtract(const Duration(seconds: 59)), now).kind, LeaveKind.leaveNow);
      expect(leaveState(now.subtract(const Duration(seconds: 61)), now).departed, isTrue);
    });

    test('departed itineraries sink to the end, order otherwise stable', () {
      final a = _it('a', now.subtract(const Duration(minutes: 5)), [_leg(transit: true, start: now.subtract(const Duration(minutes: 5)), minutes: 30, routeId: 'X')]);
      final b = _it('b', now.add(const Duration(minutes: 3)), [_leg(transit: true, start: now.add(const Duration(minutes: 3)), minutes: 30, routeId: 'X')]);
      final c = _it('c', now.add(const Duration(minutes: 9)), [_leg(transit: true, start: now.add(const Duration(minutes: 9)), minutes: 30, routeId: 'X')]);
      expect(demoteDeparted([a, b, c], now).map((i) => i.id), ['b', 'c', 'a']);
      expect(departedCount([a, b, c], now), 1);
      expect(departedCount([a, b, c], now.add(const Duration(minutes: 20))), 3);
    });
  });

  group('scenario grouping', () {
    Itinerary transit(String id, {required int minutes, int walk = 500, int transfers = 0, num? fare}) =>
        _it(id, now, [_leg(transit: true, start: now, minutes: minutes, routeId: 'R$id')], walk: walk, transfers: transfers, fare: fare);

    test('every itinerary lands in exactly one section, in display order', () {
      final its = [
        transit('fast', minutes: 30, walk: 900, transfers: 1, fare: 3200),
        transit('walkless', minutes: 40, walk: 200, transfers: 1, fare: 3200),
        transit('direct', minutes: 45, walk: 900, transfers: 0, fare: 3200),
        transit('cheap', minutes: 50, walk: 900, transfers: 1, fare: 2000),
        transit('leftover', minutes: 55, walk: 950, transfers: 2, fare: 3200),
        _it('bike', now, [
          _leg(transit: false, start: now, minutes: 10, mode: TravelMode.bicycle,
              rental: const LegRental(networkId: 'n', networkName: 'Bici', color: '#00A859')),
          _leg(transit: true, start: now.add(const Duration(minutes: 10)), minutes: 20, routeId: 'RB'),
        ]),
        _it('taxi', now, [
          _leg(transit: false, start: now, minutes: 18, mode: TravelMode.car,
              onDemand: const LegOnDemand(kind: 'taxi', providers: [], recommendedProviderId: 'taxi')),
        ]),
      ];
      final groups = groupByScenario(its);
      expect(groups.map((g) => g.scenario), [
        Scenario.fastest, Scenario.lessWalking, Scenario.fewerTransfers, Scenario.cheapest, Scenario.bike, Scenario.onDemand,
      ]);
      final ids = [for (final g in groups) ...g.all.map((i) => i.id)];
      expect(ids.toSet().length, ids.length, reason: 'no duplicates');
      expect(ids.toSet(), its.map((i) => i.id).toSet(), reason: 'nothing dropped');
      expect(groups[0].best.id, 'fast');
      expect(groups[0].rest.map((i) => i.id), ['leftover']);
      expect(groups[1].best.id, 'walkless');
      expect(groups[2].best.id, 'direct');
      expect(groups[3].best.id, 'cheap');
      expect(groups[4].best.id, 'bike');
      expect(groups[5].best.id, 'taxi');
    });

    test('axis sections are omitted when nothing beats the fastest', () {
      final its = [
        transit('a', minutes: 30, walk: 300, transfers: 0, fare: 3200),
        transit('b', minutes: 35, walk: 600, transfers: 1, fare: 3200),
        transit('c', minutes: 40, walk: 700, transfers: 2, fare: 3200),
      ];
      final groups = groupByScenario(its);
      expect(groups.map((g) => g.scenario), [Scenario.fastest]);
      expect(groups.single.rest.map((i) => i.id), ['b', 'c']);
    });

    test('cheapest needs differing fares', () {
      final its = [
        transit('a', minutes: 30, fare: 3200),
        transit('b', minutes: 45, fare: 3200),
      ];
      expect(groupByScenario(its).map((g) => g.scenario), [Scenario.fastest]);
      expect(groupByScenario(its).first.rest.length, 1);
    });

    test('empty input', () => expect(groupByScenario(const []), isEmpty));
  });

  group('re-timing', () {
    test('shifts the chosen leg, the walk before it and everything after', () {
      final walk = _leg(transit: false, start: now, minutes: 5);
      final bus = _leg(transit: true, start: now.add(const Duration(minutes: 5)), minutes: 20, routeId: 'R1', stopId: 's1');
      final walk2 = _leg(transit: false, start: now.add(const Duration(minutes: 25)), minutes: 3);
      final it = _it('x', now, [walk, bus, walk2]);
      final later = now.add(const Duration(minutes: 13));
      final r = retimeItinerary(it, 1, later, realtime: true, tripId: 't9');
      expect(r.retimed, isTrue);
      expect(r.legs[1].startTime, later);
      expect(r.legs[0].startTime, now.add(const Duration(minutes: 8)), reason: 'walk before shifts too');
      expect(r.legs[2].startTime, now.add(const Duration(minutes: 33)));
      expect(r.startTime, now.add(const Duration(minutes: 8)));
      expect(r.endTime, now.add(const Duration(minutes: 36)));
      expect(r.durationSeconds, 28 * 60);
      expect(r.legs[1].realtime, isTrue);
      expect(r.legs[1].tripId, 't9');
      expect(r.legs[1].intermediateStops.first.arrival, bus.intermediateStops.first.arrival!.add(const Duration(minutes: 8)));
      expect(r.legs[1].from.departure, bus.from.departure!.add(const Duration(minutes: 8)));
    });

    test('earlier transit legs stay put', () {
      final bus1 = _leg(transit: true, start: now, minutes: 10, routeId: 'A');
      final walk = _leg(transit: false, start: now.add(const Duration(minutes: 10)), minutes: 4);
      final bus2 = _leg(transit: true, start: now.add(const Duration(minutes: 14)), minutes: 10, routeId: 'B');
      final it = _it('y', now, [bus1, walk, bus2]);
      final r = retimeItinerary(it, 2, now.add(const Duration(minutes: 20)));
      expect(r.legs[0].startTime, now);
      expect(r.legs[1].startTime, now.add(const Duration(minutes: 16)));
      expect(r.legs[2].startTime, now.add(const Duration(minutes: 20)));
      expect(r.startTime, now);
    });

    test('same time is a no-op', () {
      final bus = _leg(transit: true, start: now, minutes: 10, routeId: 'A');
      final it = _it('z', now, [bus]);
      expect(identical(retimeItinerary(it, 0, now), it), isTrue);
      expect(identical(retimeItinerary(it, 5, now), it), isTrue);
    });
  });

  group('departure chips eligibility', () {
    test('first transit leg always; later legs only when boarding within 30 min', () {
      final walk = _leg(transit: false, start: now, minutes: 3);
      final bus1 = _leg(transit: true, start: now.add(const Duration(minutes: 3)), minutes: 50, routeId: 'A');
      final bus2 = _leg(transit: true, start: now.add(const Duration(minutes: 55)), minutes: 10, routeId: 'B');
      final it = _it('c', now, [walk, bus1, bus2]);
      expect(showDeparturesFor(it, 0, now: now), isFalse);
      expect(showDeparturesFor(it, 1, now: now), isTrue);
      expect(showDeparturesFor(it, 2, now: now), isFalse);
      expect(showDeparturesFor(it, 2, now: now.add(const Duration(minutes: 40))), isTrue);
    });
  });
}
