import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/api/mock_api_client.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/utils/geo.dart';
import 'package:opentransit_mobile/core/utils/go_trip.dart';
import 'package:opentransit_mobile/core/utils/polyline.dart';
import 'package:opentransit_mobile/core/utils/share_session.dart';

import 'helpers/factories.dart';

void main() {
  group('off-route detection', () {
    final t0 = DateTime(2026, 9, 8, 9, 0);

    test('stays quiet while the user is on the route', () {
      final d = OffRouteDetector();
      expect(d.update(metersFromRoute: 20, at: t0), isFalse);
      expect(d.update(metersFromRoute: 149, at: t0.add(const Duration(minutes: 5))), isFalse);
    });

    test('needs the distance to hold, so one bad fix is ignored', () {
      final d = OffRouteDetector();
      expect(d.update(metersFromRoute: 400, at: t0), isFalse);
      // Back on route 10 s later: the excursion is forgotten.
      expect(d.update(metersFromRoute: 30, at: t0.add(const Duration(seconds: 10))), isFalse);
      // Even a long time later, a fresh single fix does not fire.
      expect(d.update(metersFromRoute: 400, at: t0.add(const Duration(minutes: 5))), isFalse);
    });

    test('fires once the distance has held for 45 s', () {
      final d = OffRouteDetector();
      expect(d.update(metersFromRoute: 300, at: t0), isFalse);
      expect(d.update(metersFromRoute: 300, at: t0.add(const Duration(seconds: 44))), isFalse);
      expect(d.update(metersFromRoute: 300, at: t0.add(const Duration(seconds: 45))), isTrue);
    });

    test('reset clears the excursion', () {
      final d = OffRouteDetector();
      d.update(metersFromRoute: 300, at: t0);
      d.reset();
      expect(d.update(metersFromRoute: 300, at: t0.add(const Duration(seconds: 50))), isFalse);
    });

    test('reports how long the user has been away', () {
      final d = OffRouteDetector();
      d.update(metersFromRoute: 300, at: t0);
      expect(d.awaySeconds(t0.add(const Duration(seconds: 30))), 30);
    });
  });

  group('distance to a leg', () {
    test('measures to the shape, not just the endpoints', () {
      // An L-shaped leg: east along a parallel, then north.
      final shape = encodePolyline(const [
        LatLng(4.600, -74.100),
        LatLng(4.600, -74.090),
        LatLng(4.610, -74.090),
      ]);
      final l = leg(
        from: const LatLng(4.600, -74.100),
        to: const LatLng(4.610, -74.090),
        geometry: Geometry(encoded: shape),
      );

      // A point sitting on the corner is on the route.
      expect(metersFromLeg(l, const LatLng(4.600, -74.090)), lessThan(20));
      // A point inside the "L" is far from the drawn path even though it is
      // close to the straight line between the endpoints.
      expect(metersFromLeg(l, const LatLng(4.6085, -74.0995)), greaterThan(400));
    });

    test('falls back to the endpoints when the leg has no shape', () {
      final l = leg(from: const LatLng(4.600, -74.100), to: const LatLng(4.610, -74.100));
      expect(metersFromLeg(l, const LatLng(4.600, -74.100)), lessThan(5));
    });
  });

  group('distanceToSegmentMeters', () {
    test('is zero on the segment and clamps past the ends', () {
      const a = LatLng(4.600, -74.100);
      const b = LatLng(4.600, -74.090);
      expect(distanceToSegmentMeters(const LatLng(4.600, -74.095), a, b), lessThan(2));
      // Past `b`: the answer is the distance to `b`, not to the infinite line.
      final past = distanceToSegmentMeters(const LatLng(4.600, -74.080), a, b);
      expect(past, closeTo(haversineMeters(const LatLng(4.600, -74.080), b), 5));
    });
  });

  group('trip receipt', () {
    test('compares actual against planned', () {
      final it = itinerary(legs: [leg(minutes: 30, distanceMeters: 5000)]);
      final r = buildReceipt(itinerary: it, actualSeconds: it.durationSeconds + 300, completed: true);
      expect(r.plannedSeconds, it.durationSeconds);
      expect(r.deltaSeconds, 300);
      expect(r.completed, isTrue);
    });

    test('credits CO2 for transit and walking, none for a car leg', () {
      final transit = itinerary(legs: [
        leg(mode: TravelMode.bus, transit: true, distanceMeters: 10000),
      ]);
      final walk = itinerary(legs: [leg(mode: TravelMode.walk, distanceMeters: 10000)]);
      final car = itinerary(legs: [leg(mode: TravelMode.car, distanceMeters: 10000)]);

      // 10 km: walking saves the whole car footprint, the bus saves the
      // difference, the car saves nothing.
      expect(walk.legs.first.distanceMeters, 10000);
      expect(buildReceipt(itinerary: walk, actualSeconds: 0, completed: true).co2SavedGrams, 1700);
      expect(buildReceipt(itinerary: transit, actualSeconds: 0, completed: true).co2SavedGrams, 1100);
      expect(buildReceipt(itinerary: car, actualSeconds: 0, completed: true).co2SavedGrams, 0);
    });

    test('sums the distance of every leg', () {
      final it = itinerary(legs: [
        leg(distanceMeters: 400),
        leg(mode: TravelMode.bus, transit: true, distanceMeters: 6000),
        leg(distanceMeters: 300),
      ]);
      expect(buildReceipt(itinerary: it, actualSeconds: 0, completed: false).distanceMeters, 6700);
    });
  });

  group('share progress', () {
    test('coarsens coordinates before they leave the device', () {
      final p = ShareProgress.at(
        legIndex: 1,
        latitude: 4.6766123,
        longitude: -74.0483987,
        etaAt: DateTime(2026, 9, 8, 9, 30),
      );
      expect(p.lat, 4.677);
      expect(p.lon, -74.048);
      final json = p.toJson();
      expect(json['lat'], 4.677);
      expect(json['state'], 'on_time');
    });
  });

  group('share session', () {
    late MockApiClient api;
    setUp(() => api = MockApiClient());

    test('creates the link, pushes progress and revokes', () async {
      final s = ShareSession(api, 'bogota');
      final it = itinerary();
      final trip = await s.start(it, progress: () => const ShareProgress(legIndex: 0));
      expect(trip, isNotNull);
      expect(s.isActive, isTrue);
      expect(api.shares.single['token'], trip!.token);

      await s.push();
      expect((api.shares.single['patches'] as List).length, 1);

      await s.revoke();
      expect(api.shares.single['revoked'], isTrue);
      expect(s.isActive, isFalse);
      s.dispose();
    });

    test('finish marks the trip arrived for viewers', () async {
      final s = ShareSession(api, 'bogota');
      await s.start(itinerary(), progress: () => const ShareProgress(legIndex: 2));
      await s.finish(ShareState.arrived);
      final patches = api.shares.single['patches'] as List;
      expect((patches.last as Map)['state'], 'arrived');
      s.dispose();
    });

    test('starting twice reuses the same link', () async {
      final s = ShareSession(api, 'bogota');
      final a = await s.start(itinerary(), progress: () => const ShareProgress(legIndex: 0));
      final b = await s.start(itinerary(), progress: () => const ShareProgress(legIndex: 0));
      expect(identical(a, b), isTrue);
      expect(api.shares.length, 1);
      s.dispose();
    });

    test('a failing API never breaks the trip', () async {
      final s = ShareSession(_BrokenApi(), 'bogota');
      expect(await s.start(itinerary(), progress: () => const ShareProgress(legIndex: 0)), isNull);
      // Pushing and revoking without a session are no-ops, not throws.
      await s.push();
      await s.revoke();
      s.dispose();
    });
  });
}

/// A client whose share endpoints always fail.
class _BrokenApi extends MockApiClient {
  @override
  Future<SharedTrip> createShare(String cityId, Itinerary itinerary,
          {String? label, DateTime? startedAt}) async =>
      throw Exception('boom');
}
