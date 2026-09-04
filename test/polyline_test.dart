import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/models/common.dart';
import 'package:opentransit_mobile/core/utils/geo.dart';
import 'package:opentransit_mobile/core/utils/polyline.dart';

void main() {
  test('decodes the canonical Google example', () {
    final pts = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(pts, hasLength(3));
    expect(pts[0].lat, closeTo(38.5, 1e-5));
    expect(pts[0].lon, closeTo(-120.2, 1e-5));
    expect(pts[1].lat, closeTo(40.7, 1e-5));
    expect(pts[1].lon, closeTo(-120.95, 1e-5));
    expect(pts[2].lat, closeTo(43.252, 1e-5));
    expect(pts[2].lon, closeTo(-126.453, 1e-5));
  });

  test('round-trips Bogotá coordinates', () {
    const pts = [
      LatLng(4.7546, -74.0459),
      LatLng(4.6858, -74.0553),
      LatLng(4.5978, -74.1616),
    ];
    final enc = encodePolyline(pts);
    final dec = decodePolyline(enc);
    expect(dec, hasLength(3));
    for (var i = 0; i < 3; i++) {
      expect(dec[i].lat, closeTo(pts[i].lat, 1e-5));
      expect(dec[i].lon, closeTo(pts[i].lon, 1e-5));
    }
  });

  test('precision 6', () {
    const pts = [LatLng(4.123456, -74.654321), LatLng(4.123457, -74.654320)];
    final dec = decodePolyline(encodePolyline(pts, precision: 6), precision: 6);
    expect(dec[1].lat, closeTo(4.123457, 1e-6));
  });

  test('empty geometry decodes to empty list', () {
    expect(decodeGeometry(const Geometry(encoded: '')), isEmpty);
  });

  test('haversine and bounds', () {
    final d = haversineMeters(const LatLng(4.7546, -74.0459), const LatLng(4.5978, -74.1616));
    expect(d, closeTo(21500, 500));
    final b = boundsOf(const [LatLng(1, 2), LatLng(3, -1)])!;
    expect(b, [-1, 1, 2, 3]);
    expect(boundsOf(const []), isNull);
    expect(formatDistance(950), '950 m');
    expect(formatDistance(1250), '1.3 km');
  });
}
