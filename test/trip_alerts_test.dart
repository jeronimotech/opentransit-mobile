library;

/// Alerts during a trip in progress.
///
/// Asked for by TransMilenio against 1.16.0 (1.5): alerts were read when the trip was planned and
/// never again, so a closure published while the rider was on the first bus reached them as a
/// surprise at the transfer.
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/utils/trip_alerts.dart';

import 'helpers/factories.dart';

final _nine = DateTime(2026, 10, 9, 9, 0);

/// Walk to the stop, ride B74, walk to the door. Legs run 09:00 → 09:30.
Itinerary _trip() => itinerary(start: _nine, legs: [
      leg(start: _nine, minutes: 10, fromStopId: null, toStopId: 'S1', toName: 'Portal'),
      leg(
        start: _nine.add(const Duration(minutes: 10)),
        minutes: 15,
        mode: TravelMode.bus,
        transit: true,
        route: routeRef(id: 'bogota:B74', shortName: 'B74'),
        fromStopId: 'S1',
        toStopId: 'S2',
        intermediateStops: [Place(name: 'Calle 45', position: const LatLng(4.62, -74.07), stopId: 'S9')],
      ),
      leg(start: _nine.add(const Duration(minutes: 25)), minutes: 5, fromStopId: 'S2'),
    ]);

void main() {
  test('an alert on a route still ahead is reported', () {
    final out = alertsAhead(_trip(), 0, [alert(id: 'a1', routeIds: ['bogota:B74'])], now: _nine);
    expect(out.map((a) => a.id), ['a1']);
  });

  test('an alert on a stop still ahead is reported, intermediate stops included', () {
    final out = alertsAhead(_trip(), 0, [alert(id: 'a1', stopIds: ['S9'])], now: _nine);
    expect(out.map((a) => a.id), ['a1']);
  });

  test('an alert on nothing in the trip is not reported', () {
    expect(alertsAhead(_trip(), 0, [alert(id: 'a1', routeIds: ['bogota:K43'])], now: _nine), isEmpty);
  });

  test('the leg being ridden counts as ahead', () {
    // A diversion on the bus you are on is the alert that matters most.
    final out = alertsAhead(_trip(), 1, [alert(id: 'a1', routeIds: ['bogota:B74'])], now: _nine);
    expect(out.map((a) => a.id), ['a1']);
  });

  test('a leg already behind is dropped', () {
    // News the rider cannot act on. The bus leg is index 1, so from the last leg it is behind.
    final out = alertsAhead(_trip(), 2, [alert(id: 'a1', routeIds: ['bogota:B74'])], now: _nine);
    expect(out, isEmpty);
  });

  test('an alert that starts before the trip ends is reported, not only one in force now', () {
    // It begins in twenty minutes and the rider is on that platform in twenty-five.
    final out = alertsAhead(
      _trip(),
      0,
      [alert(id: 'a1', stopIds: ['S2'], start: _nine.add(const Duration(minutes: 20)))],
      now: _nine,
    );
    expect(out.map((a) => a.id), ['a1']);
  });

  test('an alert that ends before the rider sets off is dropped', () {
    final out = alertsAhead(
      _trip(),
      0,
      [alert(id: 'a1', routeIds: ['bogota:B74'], end: _nine.subtract(const Duration(minutes: 5)))],
      now: _nine,
    );
    expect(out, isEmpty);
  });

  test('an alert that starts after the trip is over is dropped', () {
    final out = alertsAhead(
      _trip(),
      0,
      [alert(id: 'a1', routeIds: ['bogota:B74'], start: _nine.add(const Duration(hours: 3)))],
      now: _nine,
    );
    expect(out, isEmpty);
  });

  test('the same alert reaching the trip twice is one entry', () {
    final a = alert(id: 'a1', routeIds: ['bogota:B74'], stopIds: ['S9']);
    expect(alertsAhead(_trip(), 0, [a, a], now: _nine), hasLength(1));
  });

  test('the worst alert comes first', () {
    final out = alertsAhead(_trip(), 0, [
      alert(id: 'info', routeIds: ['bogota:B74'], severity: AlertSeverity.info),
      alert(id: 'severe', routeIds: ['bogota:B74'], severity: AlertSeverity.severe),
      alert(id: 'warn', routeIds: ['bogota:B74'], severity: AlertSeverity.warning),
    ], now: _nine);
    expect(out.map((a) => a.id), ['severe', 'warn', 'info']);
  });

  group('what the rider has not seen', () {
    test('an alert the plan already carried is not new', () {
      final known = alert(id: 'a1', routeIds: ['bogota:B74']);
      final trip = itinerary(start: _nine, legs: [
        leg(
          start: _nine,
          mode: TravelMode.bus,
          transit: true,
          route: routeRef(id: 'bogota:B74', shortName: 'B74'),
          fromStopId: 'S1',
          toStopId: 'S2',
          alerts: [known],
        ),
      ]);
      final ahead = alertsAhead(trip, 0, [known], now: _nine);
      expect(ahead, hasLength(1));
      expect(alertsSincePlanning(trip, ahead), isEmpty);
    });

    test('an alert published after departure is new', () {
      final trip = _trip();
      final ahead = alertsAhead(trip, 0, [alert(id: 'fresh', routeIds: ['bogota:B74'])], now: _nine);
      expect(alertsSincePlanning(trip, ahead).map((a) => a.id), ['fresh']);
    });
  });

  test('an expired alert is dropped from a list that is still on screen', () {
    final a = alert(id: 'a1', routeIds: ['bogota:B74'], end: _nine);
    expect(activeNow([a], _nine.add(const Duration(minutes: 1))), isEmpty);
    expect(activeNow([a], _nine.subtract(const Duration(minutes: 1))), hasLength(1));
  });
}
