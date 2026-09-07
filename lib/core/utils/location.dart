import 'package:geolocator/geolocator.dart';

import '../models/common.dart';

class LocationDenied implements Exception {
  const LocationDenied();
}

/// Set by the screenshot walkthrough only. `flutter drive` reinstalls the app,
/// which resets the simulator's location authorisation, and a system prompt
/// cannot be dismissed from Dart — it would cover every screenshot taken after
/// GO starts. With this on, the app skips the permission request and works
/// with whatever authorisation the simulator already has.
bool skipLocationPrompt = false;

/// Returns the device position, asking for permission when needed.
/// Throws [LocationDenied] if the user refused or services are off.
Future<LatLng> currentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) throw const LocationDenied();
  var p = await Geolocator.checkPermission();
  if (p == LocationPermission.denied && !skipLocationPrompt) {
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

/// The device position, but only when the user has *already* granted it.
///
/// The assistant may enrich a question with "from here", and a question is
/// never a good reason to raise a system permission prompt: if the app does
/// not have location yet, the model simply plans from a named place instead.
/// Returns null on any refusal, timeout or platform error.
Future<LatLng?> grantedPosition() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    final p = await Geolocator.checkPermission();
    if (p != LocationPermission.always && p != LocationPermission.whileInUse) {
      return null;
    }
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) return LatLng(last.latitude, last.longitude);
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 5),
      ),
    );
    return LatLng(pos.latitude, pos.longitude);
  } catch (_) {
    return null;
  }
}
