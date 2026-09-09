// Auto-selecting a city from the device position.
//
// The rule is bbox containment, not nearest centre: a bbox is the area a feed
// actually covers, so a position inside it can be served. Nearest centre would hand
// someone in Montréal the Toronto app and then fail to plan a single trip.
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/features/cities/city_for_position.dart';

City _city(String id, List<double> bbox, LatLng centre) => City.fromJson({
      'id': id,
      'name': id,
      'country': 'XX',
      'timezone': 'UTC',
      'locale': 'en',
      'center': {'lat': centre.lat, 'lon': centre.lon},
      'bbox': bbox,
      'defaultZoom': 12,
      'modes': ['WALK', 'BUS'],
      'branding': {'primaryColor': '#000000'},
      'features': {},
      'agencies': [],
    });

// The real boxes, so the test fails if either city's coverage is mis-stated.
final bogota = _city('bogota', [-74.45, 3.95, -73.85, 4.90], const LatLng(4.6534, -74.0836));
final toronto = _city('toronto', [-79.6799, 43.5621, -79.0931, 43.9397], const LatLng(43.6532, -79.3832));
final all = [bogota, toronto];

void main() {
  test('a position inside a city gets that city', () {
    expect(cityForPosition(all, const LatLng(43.6532, -79.3832))?.id, 'toronto'); // Union Station
    expect(cityForPosition(all, const LatLng(4.6097, -74.0817))?.id, 'bogota'); // La Candelaria
  });

  test('a position we do not cover gets nothing, not the nearest city', () {
    // Montréal is 500 km from Toronto and the closest city we have. Handing it over
    // would look like it worked and then fail to plan a single trip.
    expect(cityForPosition(all, const LatLng(45.5017, -73.5673)), isNull);
    // Medellín, likewise, is not Bogotá.
    expect(cityForPosition(all, const LatLng(6.2442, -75.5812)), isNull);
    expect(cityForPosition(all, const LatLng(0, 0)), isNull);
  });

  test('the edge of a bbox is inside it', () {
    expect(cityForPosition(all, const LatLng(43.5621, -79.6799))?.id, 'toronto');
    expect(cityForPosition(all, const LatLng(43.9397, -79.0931))?.id, 'toronto');
  });

  test('where boxes overlap the smaller one wins', () {
    // A neighbouring deployment will overlap one day; the more specific one is the
    // better answer for someone standing in it.
    final region = _city('region', [-80.0, 43.0, -78.0, 44.5], const LatLng(43.7, -79.4));
    expect(cityForPosition([region, toronto], const LatLng(43.6532, -79.3832))?.id, 'toronto');
    // ...and outside the smaller one, the bigger still answers.
    expect(cityForPosition([region, toronto], const LatLng(43.2, -79.5))?.id, 'region');
  });

  test('an empty list is not an error', () {
    expect(cityForPosition(const [], const LatLng(43.65, -79.38)), isNull);
  });

  test('distance to a city is only ever a hint', () {
    expect(kmToCity(toronto, const LatLng(43.6532, -79.3832)), lessThan(1));
    expect(kmToCity(toronto, const LatLng(45.5017, -73.5673)), greaterThan(400));
  });
}
