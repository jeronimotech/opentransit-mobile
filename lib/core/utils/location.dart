import 'package:geolocator/geolocator.dart';

import '../models/common.dart';

class LocationDenied implements Exception {
  const LocationDenied();
}

/// Returns the device position, asking for permission when needed.
/// Throws [LocationDenied] if the user refused or services are off.
Future<LatLng> currentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) throw const LocationDenied();
  var p = await Geolocator.checkPermission();
  if (p == LocationPermission.denied) {
    p = await Geolocator.requestPermission();
  }
  if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
    throw const LocationDenied();
  }
  final pos = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 10),
    ),
  );
  return LatLng(pos.latitude, pos.longitude);
}
