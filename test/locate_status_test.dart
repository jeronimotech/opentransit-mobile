// "Ubica tu bus" status line: explains "Programado" rows from the API's
// vehiclesOnRoute count (or the live frame) and the next-bus sources.
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/features/locate/locate_status.dart';

import 'helpers/fixtures.dart';

void main() {
  final nextFixture = NextBusesResponse.fromJson(loadFixture('next'));
  final frame = VehicleFrame.fromJson(loadFixture('vehicles'));
  NextBus sched(int m) => NextBus(minutes: m, time: DateTime(2026, 9, 4, 8, m), source: 'scheduled');

  test('fixture carries vehiclesOnRoute and servesStop', () {
    expect(nextFixture.vehiclesOnRoute, greaterThan(0));
    expect(nextFixture.servesStop, isTrue);
  });

  test('no live buses on the route', () {
    expect(locateStatus(vehiclesOnRoute: 0, next: [sched(5), sched(15)]), const LocateStatus(LocateStatusKind.noLive));
    expect(locateStatus(vehiclesOnRoute: 0, next: const []), const LocateStatus(LocateStatusKind.noLive));
  });

  test('buses on the route but only scheduled rows → none coming yet', () {
    expect(locateStatus(vehiclesOnRoute: 3, next: [sched(5), sched(15)]),
        const LocateStatus(LocateStatusKind.noneComing, onRoute: 3));
  });

  test('live/estimated rows with a vehicle count as coming', () {
    final s = locateStatus(vehiclesOnRoute: 7, next: nextFixture.next);
    expect(s.kind, LocateStatusKind.coming);
    expect(s.onRoute, 7);
    expect(s.coming, 2, reason: 'one live + one estimated row carry a vehicle; the scheduled row does not');
  });

  test('coming never exceeds the reported count', () {
    final s = locateStatus(vehiclesOnRoute: 1, next: nextFixture.next);
    expect(s.onRoute, 2);
    expect(s.coming, 2);
  });

  test('without the API count the live frame is counted by route id / short name', () {
    final ids = frame.vehicles.values.map((v) => v.routeId).whereType<String>().toSet().toList();
    final b10 = ids.firstWhere((id) => id.contains('B10'));
    final onB10 = frame.vehicles.values.where((v) => v.routeId == b10).length;
    final s = locateStatus(next: [sched(5)], frame: frame, routeIds: [b10]);
    expect(s, LocateStatus(LocateStatusKind.noneComing, onRoute: onB10));
    expect(locateStatus(next: [sched(5)], frame: frame, routeIds: const ['bogota:nope']), const LocateStatus(LocateStatusKind.noLive));
    expect(locateStatus(next: [sched(5)], frame: frame, shortName: 'B10').onRoute, onB10);
  });

  test('no count at all falls back to the rows', () {
    expect(locateStatus(next: [sched(5)]), const LocateStatus(LocateStatusKind.noLive));
    expect(locateStatus(next: nextFixture.next).kind, LocateStatusKind.coming);
  });
}
