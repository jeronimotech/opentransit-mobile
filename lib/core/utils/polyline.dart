import '../models/common.dart';

/// Decodes a Google encoded polyline into a list of [LatLng].
///
/// [precision] is the number of decimal digits used when encoding (5 for the
/// classic algorithm, 6 for some newer producers).
List<LatLng> decodePolyline(String encoded, {int precision = 5}) {
  final factor = _pow10(precision);
  final out = <LatLng>[];
  var index = 0, lat = 0, lng = 0;
  while (index < encoded.length) {
    int shift = 0, result = 0, b;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    out.add(LatLng(lat / factor, lng / factor));
  }
  return out;
}

/// Encodes a list of [LatLng] with the same algorithm (used in tests and to
/// build share links).
String encodePolyline(List<LatLng> points, {int precision = 5}) {
  final factor = _pow10(precision);
  final sb = StringBuffer();
  var plat = 0, plng = 0;
  for (final p in points) {
    final lat = (p.lat * factor).round();
    final lng = (p.lon * factor).round();
    _encodeValue(lat - plat, sb);
    _encodeValue(lng - plng, sb);
    plat = lat;
    plng = lng;
  }
  return sb.toString();
}

void _encodeValue(int value, StringBuffer sb) {
  var v = value < 0 ? ~(value << 1) : (value << 1);
  while (v >= 0x20) {
    sb.writeCharCode((0x20 | (v & 0x1f)) + 63);
    v >>= 5;
  }
  sb.writeCharCode(v + 63);
}

int _pow10(int n) {
  var r = 1;
  for (var i = 0; i < n; i++) {
    r *= 10;
  }
  return r;
}

List<LatLng> decodeGeometry(Geometry g) =>
    g.encoded.isEmpty ? const [] : decodePolyline(g.encoded, precision: g.precision);
