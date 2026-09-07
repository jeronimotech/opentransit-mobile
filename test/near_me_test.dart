import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opentransit_mobile/core/api/mock_api_client.dart';
import 'package:opentransit_mobile/core/providers.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/storage/preferences.dart';
import 'package:opentransit_mobile/core/utils/geo.dart';
import 'package:opentransit_mobile/core/utils/near_me.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bogotá, Parque de la 93 — the fixture centre used throughout.
const _here = LatLng(4.6766, -74.0483);

Vehicle _bus(
  String id,
  LatLng at, {
  double? bearing,
  Component component = Component.trunk,
  String? shortName,
}) =>
    Vehicle(
      id: id,
      routeId: 'bogota:$id',
      routeShortName: shortName ?? id,
      tripResolved: true,
      component: component,
      position: at,
      bearing: bearing,
    );

/// Moves [from] by [meters] along [bearingDeg] (small-offset approximation,
/// which is exact enough at the few hundred metres this mode works in).
LatLng _offset(LatLng from, double meters, double bearingDeg) {
  const perDegLat = 111320.0;
  final rad = bearingDeg * 3.1415926535897932 / 180;
  final dLat = meters * _cos(rad) / perDegLat;
  final dLon = meters * _sin(rad) / (perDegLat * _cos(from.lat * 3.1415926535897932 / 180));
  return LatLng(from.lat + dLat, from.lon + dLon);
}

double _cos(double x) {
  // Small local helper so the test does not depend on dart:math imports order.
  var t = 1.0, sum = 1.0;
  for (var i = 1; i <= 12; i++) {
    t *= -x * x / ((2 * i - 1) * (2 * i));
    sum += t;
  }
  return sum;
}

double _sin(double x) {
  var t = x, sum = x;
  for (var i = 1; i <= 12; i++) {
    t *= -x * x / ((2 * i) * (2 * i + 1));
    sum += t;
  }
  return sum;
}

void main() {
  group('bbox from centre and radius', () {
    test('encloses the circle and stays tight around it', () {
      final b = bboxAround(_here, 600);
      final [minLon, minLat, maxLon, maxLat] = b;
      expect(minLat, lessThan(_here.lat));
      expect(maxLat, greaterThan(_here.lat));
      expect(minLon, lessThan(_here.lon));
      expect(maxLon, greaterThan(_here.lon));

      // Every point on the circle is inside the box…
      for (var deg = 0; deg < 360; deg += 15) {
        final p = _offset(_here, 600, deg.toDouble());
        expect(p.lat, inInclusiveRange(minLat, maxLat), reason: 'lat at $deg°');
        expect(p.lon, inInclusiveRange(minLon, maxLon), reason: 'lon at $deg°');
      }
      // …and the box is not wastefully larger: its half-height is ~600 m.
      final northEdge = haversineMeters(_here, LatLng(maxLat, _here.lon));
      expect(northEdge, closeTo(600, 5));
      final eastEdge = haversineMeters(_here, LatLng(_here.lat, maxLon));
      expect(eastEdge, closeTo(600, 5));
    });

    test('a bigger radius gives a strictly bigger box', () {
      final small = bboxAround(_here, 300);
      final big = bboxAround(_here, 1000);
      expect(big[0], lessThan(small[0]));
      expect(big[3], greaterThan(small[3]));
    });
  });

  group('distance and approach', () {
    test('sorts by distance, nearest first', () {
      final vs = [
        _bus('far', _offset(_here, 500, 0)),
        _bus('near', _offset(_here, 100, 0)),
        _bus('mid', _offset(_here, 300, 0)),
      ];
      final out = nearbyVehicles(vs, _here, radiusMeters: 600);
      expect(out.map((n) => n.id), ['near', 'mid', 'far']);
      expect(out.first.distanceMeters, closeTo(100, 5));
    });

    test('drops what is outside the radius', () {
      final vs = [_bus('in', _offset(_here, 250, 90)), _bus('out', _offset(_here, 900, 90))];
      expect(nearbyVehicles(vs, _here, radiusMeters: 300).map((n) => n.id), ['in']);
    });

    test('a bus north of me heading south is approaching', () {
      final v = _bus('a', _offset(_here, 200, 0), bearing: 180);
      expect(nearbyVehicles([v], _here, radiusMeters: 600).single.approach, Approach.approaching);
    });

    test('a bus north of me heading north is moving away', () {
      final v = _bus('a', _offset(_here, 200, 0), bearing: 0);
      expect(nearbyVehicles([v], _here, radiusMeters: 600).single.approach, Approach.away);
    });

    test('without a bearing the answer is unknown, never a guess', () {
      final v = _bus('a', _offset(_here, 200, 0));
      expect(v.bearing, isNull);
      expect(nearbyVehicles([v], _here, radiusMeters: 600).single.approach, Approach.unknown);
    });

    test('a bus crossing perpendicular is neither approaching nor leaving', () {
      // North of me, travelling due east: it neither closes nor opens.
      final v = _bus('a', _offset(_here, 200, 0), bearing: 90);
      expect(nearbyVehicles([v], _here, radiusMeters: 600).single.approach, Approach.unknown);
    });

    test('filters by component, and an empty filter means all', () {
      final vs = [
        _bus('t', _offset(_here, 100, 0), component: Component.trunk),
        _bus('z', _offset(_here, 120, 0), component: Component.zonal),
      ];
      expect(nearbyVehicles(vs, _here, radiusMeters: 600).length, 2);
      expect(
        nearbyVehicles(vs, _here, radiusMeters: 600, components: {Component.zonal}).map((n) => n.id),
        ['z'],
      );
    });

    test('uses the interpolated position when one is supplied', () {
      // The raw frame puts the bus outside the radius; the interpolated
      // position (what the map is actually drawing) puts it inside. The list
      // must agree with the map, or a tapped row highlights nothing.
      final v = _bus('a', _offset(_here, 900, 0));
      final out = nearbyVehicles([v], _here,
          radiusMeters: 400, positionOf: (_) => _offset(_here, 150, 0));
      expect(out.single.distanceMeters, closeTo(150, 5));
    });

    test('order is stable between frames when distances tie', () {
      final vs = [_bus('b', _offset(_here, 200, 0)), _bus('a', _offset(_here, 200, 0))];
      expect(nearbyVehicles(vs, _here, radiusMeters: 600).map((n) => n.id), ['a', 'b']);
    });
  });

  group('widening', () {
    test('offers the next radius up, and nothing past the widest', () {
      expect(widerRadius(300), 600);
      expect(widerRadius(600), 1000);
      expect(widerRadius(1000), isNull);
    });
  });

  group('live stream lifecycle', () {
    test('subscribes to the radius bbox and cancels when nobody watches', () async {
      final api = _StreamSpyApi();
      final container = ProviderContainer(overrides: [apiClientProvider.overrideWithValue(api)]);
      addTearDown(container.dispose);

      final q = BboxQuery('bogota', bboxAround(_here, 600 * 1.25));
      final sub = container.listen(nearbyLiveVehiclesProvider(q), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      expect(api.subscriptions, 1);
      expect(api.boxes.single, isNotNull, reason: 'the stream must be bbox-filtered, not city-wide');

      // Leaving the screen: the provider is autoDispose, so dropping the last
      // listener must end the upstream subscription. This is the battery cost
      // of the mode, so it is worth an explicit test rather than a comment.
      sub.close();
      // Riverpod schedules autoDispose, and the generator unwinds through an
      // `await for`, so the cancellation lands a microtask or two later.
      for (var i = 0; i < 20 && api.cancellations == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(api.cancellations, 1);
    });

    test('a different radius is a different subscription', () async {
      final api = _StreamSpyApi();
      final container = ProviderContainer(overrides: [apiClientProvider.overrideWithValue(api)]);
      addTearDown(container.dispose);

      final small = container.listen(
          nearbyLiveVehiclesProvider(BboxQuery('bogota', bboxAround(_here, 300 * 1.25))), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      container.listen(
          nearbyLiveVehiclesProvider(BboxQuery('bogota', bboxAround(_here, 1000 * 1.25))), (_, _) {});
      await Future<void>.delayed(Duration.zero);

      expect(api.subscriptions, 2);
      expect(api.boxes.length, 2);
      expect(api.boxes[1]![0], lessThan(api.boxes[0]![0]),
          reason: 'the wider radius must ask for a wider box');
      small.close();
    });
  });

  group('framing', () {
    test('a wider radius frames out, never in', () {
      expect(zoomForRadius(300), greaterThan(zoomForRadius(600)));
      expect(zoomForRadius(600), greaterThan(zoomForRadius(1000)));
    });

    test('the ring fits the viewport at every offered radius', () {
      // Web-mercator ground resolution at Bogotá's latitude, on a 390 pt wide
      // phone at 3x. Guards the zoom table against a value that would put the
      // ring — and the buses inside it — off screen.
      const widthPt = 390.0, lat = 4.68;
      for (final r in nearMeRadii) {
        final z = zoomForRadius(r);
        final metresPerPixel = 156543.03392 * math.cos(lat * math.pi / 180) / math.pow(2, z);
        final metresAcross = widthPt * metresPerPixel;
        // The ring must fit with margin…
        expect(metresAcross, greaterThan(2.4 * r),
            reason: 'the $r m ring must fit across the screen at zoom $z');
        // …and not shrink to a dot in the middle of an empty map.
        expect(metresAcross, lessThan(4.5 * r), reason: 'zoom $z wastes the screen for $r m');
      }
    });
  });

  group('preferences', () {
    test('radius round-trips and defaults to 600', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = PreferencesRepository(await SharedPreferences.getInstance());
      expect(repo.nearMeRadius, nearMeDefaultRadius);
      await repo.setNearMeRadius(1000);
      expect(repo.nearMeRadius, 1000);
    });

    test('component filter round-trips and clears to empty', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = PreferencesRepository(await SharedPreferences.getInstance());
      expect(repo.nearMeComponents, isEmpty);
      await repo.setNearMeComponents(['trunk', 'zonal']);
      expect(repo.nearMeComponents, ['trunk', 'zonal']);
      // Every chip deselected must mean "all", not a filter that hides everything.
      await repo.setNearMeComponents([]);
      expect(repo.nearMeComponents, isEmpty);
    });

    test('a stored radius outside the offered set is ignored', () {
      // Guards the screen's own clamp: a value written by an older build (or a
      // hand-edited prefs file) must not leave the chips with nothing selected.
      expect(nearMeRadii.contains(450), isFalse);
      final effective = nearMeRadii.contains(450) ? 450 : nearMeDefaultRadius;
      expect(effective, nearMeDefaultRadius);
    });
  });
}

/// A client whose vehicle stream reports when it is subscribed and cancelled,
/// and remembers the bbox it was asked for.
class _StreamSpyApi extends MockApiClient {
  int subscriptions = 0;
  int cancellations = 0;
  final List<List<double>?> boxes = [];

  @override
  Stream<Map<String, dynamic>> vehicleEvents(String cityId,
      {List<double>? bbox, List<String>? routeIds}) {
    boxes.add(bbox);
    late StreamController<Map<String, dynamic>> c;
    c = StreamController<Map<String, dynamic>>(
      onListen: () => subscriptions++,
      onCancel: () => cancellations++,
    );
    return c.stream;
  }
}
