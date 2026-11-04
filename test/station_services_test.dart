import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/models/models.dart';

// The server (opentransit-api /pois/near) decides the split by tag, not distance, and
// hands back two arrays with distanceMeters + walkMinutes already on each feature. These
// tests pin that the client parses that shape faithfully — including that a POI in
// `nearby` is never silently promoted to a station facility.
Map<String, dynamic> _feat(String type, double lon, double lat,
        {String? name, int? dist, int? walk}) =>
    {
      'type': 'Feature',
      'geometry': {'type': 'Point', 'coordinates': [lon, lat]},
      'properties': {
        'id': 'osm:$type:$lon',
        'type': type,
        if (name != null) 'name': name,
        if (dist != null) 'distanceMeters': dist,
        if (walk != null) 'walkMinutes': walk,
      },
    };

void main() {
  test('parses both buckets and the distance/walk decoration', () {
    final s = StationServices.fromJson({
      'atStation': [_feat('bike_parking', -74.1, 4.6, name: 'TransMilenio', dist: 2, walk: 1)],
      'nearby': [
        _feat('pharmacy', -74.1, 4.61, dist: 126, walk: 2),
        _feat('health', -74.1, 4.62, dist: 204, walk: 3),
      ],
    });
    expect(s.isEmpty, isFalse);
    expect(s.atStation.single.type, 'bike_parking');
    expect(s.atStation.single.distanceMeters, 2);
    expect(s.atStation.single.walkMinutes, 1);
    expect(s.nearby.map((p) => p.type).toList(), ['pharmacy', 'health']);
    expect(s.nearby.first.distanceMeters, 126);
  });

  test('a nearby pharmacy stays in nearby — never in atStation', () {
    final s = StationServices.fromJson({
      'atStation': const [],
      'nearby': [_feat('pharmacy', -74.1, 4.6, dist: 20, walk: 1)],
    });
    expect(s.atStation, isEmpty);
    expect(s.nearby.single.type, 'pharmacy');
  });

  test('empty payload yields the empty split (section will not render)', () {
    final s = StationServices.fromJson({'atStation': const [], 'nearby': const []});
    expect(s.isEmpty, isTrue);
  });

  test('a bbox Poi without distance keeps nulls (walkMinutes absent)', () {
    final p = Poi.fromFeature(_feat('atm', -74.1, 4.6))!;
    expect(p.distanceMeters, isNull);
    expect(p.walkMinutes, isNull);
  });
}
