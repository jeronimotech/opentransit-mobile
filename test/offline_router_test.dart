library;

/// Planning a journey with no network.
///
/// The board bundle can say when a bus leaves and never when you arrive, because nothing in it
/// links a departure at one stop to an arrival at another. These tests are about the structure that
/// does: a pattern, and a scan over it.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/offline/offline_patterns.dart';
import 'package:opentransit_mobile/core/offline/offline_router.dart';

/// A toy network:
///
///   A ── red ──> B ── red ──> C          red: 08:00 and 08:30 from A, 10 min between stops
///   A ── blue ─> D                        blue: 08:05, direct to D (which is a 3 min walk from C)
///
/// So C is reachable two ways: ride red the whole way (arrive 08:20), or ride blue and walk
/// (arrive 08:18). Which one wins is the point of several tests below.
OfflinePatterns _net() => OfflinePatterns.parse(jsonEncode({
      'city': 'testville',
      'stops': ['A', 'B', 'C', 'D'],
      'routes': ['RED', 'BLUE'],
      'headsigns': ['East', 'North'],
      'services': ['WK'],
      'patterns': [
        {
          'r': 0, 'h': 0, 's': [0, 1, 2],
          't': [
            [0, [480, 490, 500]],   // 08:00 → 08:10 → 08:20
            [0, [510, 520, 530]],   // 08:30 → 08:40 → 08:50
          ],
        },
        {
          'r': 1, 'h': 1, 's': [0, 3],
          't': [
            [0, [485, 495]],        // 08:05 → 08:15
          ],
        },
      ],
    }));

List<List<({int stop, int minutes})>> _noWalking(int n) =>
    List.generate(n, (_) => const <({int stop, int minutes})>[]);

void main() {
  final net = _net();
  final weekday = {0};

  group('a direct ride', () {
    test('finds the first trip that has not left yet', () {
      final js = planOffline(
        data: net,
        originStops: {0},
        destinationStops: {2},
        departAfterMinute: 470,            // 07:50
        runningServices: weekday,
        footpaths: _noWalking(4),
      );
      expect(js, isNotEmpty);
      final j = js.first;
      expect(j.rides.length, 1);
      expect(j.departureMinute, 480);      // 08:00, not the 08:30
      expect(j.arrivalMinute, 500);        // 08:20
      expect(j.transfers, 0);
    });

    test('takes the later trip when the first has gone', () {
      final js = planOffline(
        data: net, originStops: {0}, destinationStops: {2},
        departAfterMinute: 495,            // 08:15, after the 08:00 left A
        runningServices: weekday, footpaths: _noWalking(4),
      );
      expect(js.first.departureMinute, 510);
      expect(js.first.arrivalMinute, 530);
    });

    test('boarding mid-route works', () {
      final js = planOffline(
        data: net, originStops: {1}, destinationStops: {2},
        departAfterMinute: 480, runningServices: weekday, footpaths: _noWalking(4),
      );
      expect(js.first.rides.single.fromStop, 1);
      expect(js.first.arrivalMinute, 500);
    });
  });

  group('when nothing runs', () {
    test('a service that is not running today is not boardable', () {
      // The calendar lives in the board bundle; the scan is told which services run and must
      // believe only that. Offering a Sunday timetable on a Tuesday is the planner lying.
      final js = planOffline(
        data: net, originStops: {0}, destinationStops: {2},
        departAfterMinute: 470, runningServices: const {}, footpaths: _noWalking(4),
      );
      expect(js, isEmpty);
    });

    test('after the last trip of the day there is no journey, not a wrong one', () {
      final js = planOffline(
        data: net, originStops: {0}, destinationStops: {2},
        departAfterMinute: 600, runningServices: weekday, footpaths: _noWalking(4),
      );
      expect(js, isEmpty);
    });

    test('an unreachable destination is empty', () {
      final js = planOffline(
        data: net, originStops: {3}, destinationStops: {2},
        departAfterMinute: 470, runningServices: weekday, footpaths: _noWalking(4),
      );
      expect(js, isEmpty);
    });

    test('no origin or no destination is empty rather than a crash', () {
      expect(planOffline(data: net, originStops: const {}, destinationStops: {2},
          departAfterMinute: 470, runningServices: weekday, footpaths: _noWalking(4)), isEmpty);
      expect(planOffline(data: net, originStops: {0}, destinationStops: const {},
          departAfterMinute: 470, runningServices: weekday, footpaths: _noWalking(4)), isEmpty);
    });
  });

  group('walking', () {
    List<List<({int stop, int minutes})>> dToC() {
      final f = _noWalking(4);
      f[3] = [(stop: 2, minutes: 3)];
      f[2] = [(stop: 3, minutes: 3)];
      return f;
    }

    test('a short walk at the end beats staying on the slower bus', () {
      // Blue reaches D at 08:15 and C is three minutes away: 08:18, against red's 08:20.
      final js = planOffline(
        data: net, originStops: {0}, destinationStops: {2},
        departAfterMinute: 470, runningServices: weekday, footpaths: dToC(),
      );
      expect(js, isNotEmpty);
      expect(js.last.arrivalMinute, lessThanOrEqualTo(498));
    });

    test('the final walk counts toward the arrival', () {
      // Blue reaches D at 08:15; C is three minutes away. The journey arrives at 08:18, not 08:15.
      // Deriving the arrival from the last ride reported the bus and was wrong by exactly the walk.
      final js = planOffline(
        data: net, originStops: {0}, destinationStops: {2},
        departAfterMinute: 470, runningServices: weekday, footpaths: dToC(),
      );
      final best = js.last;
      expect(best.arrivalMinute, 498);
      expect(best.walkMinutes, 3);
      expect(best.rides.last.arrivalMinute, 495);   // the bus got to D at 08:15
    });

    test('a faster walk replaces a slower ride whatever order the patterns were scanned in', () {
      // This failed because the walk used putIfAbsent, so whichever pattern happened to be visited
      // first kept the stop even when the other reached it sooner.
      final js = planOffline(
        data: net, originStops: {0}, destinationStops: {2},
        departAfterMinute: 470, runningServices: weekday, footpaths: dToC(),
      );
      expect(js.last.arrivalMinute, lessThan(500));
    });

    test('without the footpath the walk is not invented', () {
      final js = planOffline(
        data: net, originStops: {0}, destinationStops: {2},
        departAfterMinute: 470, runningServices: weekday, footpaths: _noWalking(4),
      );
      expect(js.first.arrivalMinute, 500);
    });
  });

  group('what it returns', () {
    test('a journey per round, so fewer transfers is also an answer', () {
      // Round k holds the best arrival using at most k boardings. A rider offered only the fastest
      // cannot choose the simpler one.
      final js = planOffline(
        data: net, originStops: {0}, destinationStops: {2},
        departAfterMinute: 470, runningServices: weekday, footpaths: _noWalking(4),
      );
      expect(js.length, greaterThanOrEqualTo(1));
      expect(js.every((j) => j.rides.isNotEmpty), isTrue);
      // Each later answer is at least as fast as the one before, or it would not have been kept.
      for (var i = 1; i < js.length; i++) {
        expect(js[i].arrivalMinute, lessThan(js[i - 1].arrivalMinute));
      }
    });

    test('a ride names the pattern it used, so a leg can be drawn', () {
      final js = planOffline(
        data: net, originStops: {0}, destinationStops: {2},
        departAfterMinute: 470, runningServices: weekday, footpaths: _noWalking(4),
      );
      final r = js.first.rides.single;
      expect(net.patterns[r.patternIndex].routeIndex, 0);
      expect(net.routes[net.patterns[r.patternIndex].routeIndex], 'RED');
    });
  });

  group('the pattern index', () {
    test('lists every pattern calling at a stop, once', () {
      expect(net.patternsAt(0).toSet(), {0, 1});   // A is on both
      expect(net.patternsAt(2), [0]);              // C only on red
      expect(net.patternsAt(3), [1]);
    });

    test('a stop out of range answers nothing instead of throwing', () {
      expect(net.patternsAt(99), isEmpty);
      expect(net.patternsAt(-1), isEmpty);
    });

    test('earliestTrip skips what has already left', () {
      final red = net.patterns[0];
      expect(red.earliestTrip(0, 470, {0})!.times[0], 480);
      expect(red.earliestTrip(0, 481, {0})!.times[0], 510);
      expect(red.earliestTrip(0, 511, {0}), isNull);
      expect(red.earliestTrip(0, 470, const {}), isNull);
    });
  });
}
