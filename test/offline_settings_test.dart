library;

/// The settings row that offers the download, and the model behind it.
///
/// The download is always an explicit tap. That is the strongest reading of "respect metered
/// connections": never spend a rider's data without asking, and put the size in the question.
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/utils/format.dart';

void main() {
  group('the size a rider is shown', () {
    test('reads the way a person reads a download, not the way a disk reports one', () {
      expect(formatBytes(512), '512 B');
      expect(formatBytes(2048), '2 KB');
      expect(formatBytes(10 * 1024), '10 KB');
      // Casablanca's whole timetable.
      expect(formatBytes(12 * 1024), '12 KB');
      // Bogotá's, the largest of the nine.
      expect(formatBytes(5672345), '5.4 MB');
      // Lisboa's.
      expect(formatBytes(4635950), '4.4 MB');
      // Past ten megabytes the tenths stop telling anyone anything.
      expect(formatBytes(23 * 1024 * 1024), '23 MB');
    });
  });

  group('a city that has a bundle, and one that does not', () {
    Map<String, dynamic> cityJson(Object? offline) => {
          'id': 'bogota',
          'name': 'Bogotá',
          'country': 'CO',
          'timezone': 'America/Bogota',
          'locale': 'es',
          'center': {'lat': 4.65, 'lon': -74.08},
          'bbox': [-74.45, 3.95, -73.85, 4.90],
          'defaultZoom': 12,
          'modes': ['WALK', 'BUS'],
          'branding': {'primaryColor': '#D32F2F'},
          'features': {},
          'agencies': [],
          'offline': offline,
        };

    test('a published bundle parses with its size', () {
      final c = City.fromJson(cityJson({
        'url': 'https://example.com/offline-bundle.ndjson.gz',
        'bytes': 5672345,
        'formatVersion': 1,
        'departures': 9560672,
        'builtAt': '2026-10-07',
      }));
      expect(c.offline, isNotNull);
      expect(c.offline!.bytes, 5672345);
      expect(c.offline!.departures, 9560672);
      expect(formatBytes(c.offline!.bytes), '5.4 MB');
    });

    test('no bundle is null, so the app offers no download rather than one that 404s', () {
      expect(City.fromJson(cityJson(null)).offline, isNull);
      // And the field being absent altogether is the same thing, which is how the nine cities
      // ship until their assets exist.
      final j = cityJson(null)..remove('offline');
      expect(City.fromJson(j).offline, isNull);
    });

    test('a bundle with no url or no size is treated as absent, not as broken', () {
      // A misconfigured entry must not produce a download button that cannot work.
      expect(City.fromJson(cityJson({'bytes': 100})).offline, isNull);
      expect(City.fromJson(cityJson({'url': 'https://x/y.gz'})).offline, isNull);
      expect(City.fromJson(cityJson({'url': '', 'bytes': 100})).offline, isNull);
      expect(City.fromJson(cityJson({'url': 'https://x/y.gz', 'bytes': 0})).offline, isNull);
    });
  });
}
