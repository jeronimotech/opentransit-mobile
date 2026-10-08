// The offline path, on a real device, against the real published bundles.
//
//   flutter test integration_test/offline_plan_live_test.dart \
//     -d <device> --dart-define=API_URL=https://api.opentransit.tech
//
// Unit tests prove the scan is right about a toy network. This proves the parts nothing on a
// desktop can: that the published artefacts download, parse, and answer a real journey in Bogotá
// with 8 311 stops and 1 521 patterns — and how long that takes on a phone, which is the number
// that decides whether the feature is usable at all.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:opentransit_mobile/core/api/http_api_client.dart';
import 'package:opentransit_mobile/core/config.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/offline/offline_plan.dart';
import 'package:opentransit_mobile/core/offline/offline_router.dart';
import 'package:opentransit_mobile/core/offline/offline_store.dart';
import 'package:opentransit_mobile/core/utils/geo.dart';

const _city = 'bogota';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('download, install and plan a Bogotá journey with no network', (tester) async {
    final api = HttpApiClient(AppConfig.apiUrl);
    final city = await api.city(_city);
    expect(city.offline, isNotNull, reason: 'no board bundle published');
    expect(city.offlinePatterns, isNotNull, reason: 'no pattern index published');

    final store = OfflineStore();
    await store.remove(_city);

    final t0 = DateTime.now();
    final meta = await store.install(_city,
        url: city.offline!.url, expectedBytes: city.offline!.bytes);
    final patternCount = await store.installPatterns(_city,
        url: city.offlinePatterns!.url, expectedBytes: city.offlinePatterns!.bytes);
    debugPrint('OFFLINE: installed in ${DateTime.now().difference(t0).inSeconds}s · '
        '${meta.departures} departures · $patternCount patterns · ${meta.stops} stops');

    final bundle = (await store.open(_city))!;
    final patterns = (await store.openPatterns(_city))!;
    expect(patterns.patterns, isNotEmpty);
    expect(patterns.stops.length, greaterThan(5000));

    // Building the walking links is the one O(stops²) step; if it is slow, it is slow here.
    final t1 = DateTime.now();
    final footpaths = buildFootpaths(bundle.header, patterns.stops);
    final links = footpaths.fold<int>(0, (a, l) => a + l.length);
    debugPrint('OFFLINE: $links footpaths in ${DateTime.now().difference(t1).inMilliseconds}ms');
    expect(links, greaterThan(0), reason: 'no stop is walkable from any other');

    // Portal Suba to the centre, a real cross-town trip, at a weekday morning hour.
    const from = LatLng(4.7430, -74.0940);
    const to = LatLng(4.6180, -74.0700);
    final day = DateTime.now();
    final services = bundle.header.activeServices(day);
    debugPrint('OFFLINE: ${services.length} services running today');

    Set<int> near(LatLng p, double metres) {
      final out = <int>{};
      for (var i = 0; i < patterns.stops.length; i++) {
        final hi = bundle.header.stopIndexById[patterns.stops[i]];
        if (hi == null) continue;
        if (haversineMeters(p, bundle.header.stops[hi].position) <= metres) out.add(i);
      }
      return out;
    }

    final origins = near(from, 600);
    final destinations = near(to, 600);
    debugPrint('OFFLINE: ${origins.length} origin stops, ${destinations.length} destination stops');
    expect(origins, isNotEmpty);
    expect(destinations, isNotEmpty);

    final t2 = DateTime.now();
    final journeys = planOffline(
      data: patterns,
      originStops: origins,
      destinationStops: destinations,
      departAfterMinute: 8 * 60,
      runningServices: services,
      footpaths: footpaths,
    );
    final ms = DateTime.now().difference(t2).inMilliseconds;
    debugPrint('OFFLINE: ${journeys.length} journeys in ${ms}ms');
    for (final j in journeys) {
      debugPrint('OFFLINE:   ${j.departureMinute ~/ 60}:${(j.departureMinute % 60).toString().padLeft(2, "0")}'
          ' -> ${j.arrivalMinute ~/ 60}:${(j.arrivalMinute % 60).toString().padLeft(2, "0")}'
          ' · ${j.transfers} transfers · ${j.walkMinutes} min walking');
    }

    expect(journeys, isNotEmpty, reason: 'no journey across Bogotá at 08:00 on a running service');
    // A cross-town trip that claims to take under ten minutes, or over four hours, is the scan
    // being wrong rather than the city being unusual.
    final best = journeys.last;
    final minutes = best.arrivalMinute - best.departureMinute;
    expect(minutes, greaterThan(10));
    expect(minutes, lessThan(240));
    // Under a second is the bar: longer and a rider would rather wait for the network.
    expect(ms, lessThan(4000), reason: 'the scan is too slow to be useful on a phone');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
