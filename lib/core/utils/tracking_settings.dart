import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// The location settings the guided trip listens with.
///
/// Asked for by TransMilenio against 1.16.0 (1.6): the get-off alert only worked with the app in
/// front, so a rider who locked the phone got no warning. [background] carries it past the lock
/// screen — and it is off unless the rider turned it on, because continuous location is the most
/// expensive thing this app can do to a battery.
///
/// On Android that is a foreground service with an ongoing notification rather than the background
/// location permission: the rider can see it running and stop it, and the app never holds a
/// permission that would let it track them with nothing on screen. On iOS it is the `location`
/// background mode under "when in use" authorisation, which keeps the blue indicator visible.
LocationSettings trackingSettings({
  required bool background,
  required String notificationTitle,
  required String notificationText,
}) {
  if (!background) {
    return const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 10);
  }
  // `defaultTargetPlatform` rather than `dart:io Platform`, so this stays usable in tests and on
  // the web build without an abstract-platform error.
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: notificationTitle,
          notificationText: notificationText,
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    case TargetPlatform.iOS:
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
        // The system would otherwise pause updates when it decides the rider has stopped moving,
        // which on a bus in traffic is exactly when the next stop is about to be theirs.
        pauseLocationUpdatesAutomatically: false,
      );
    default:
      return const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 10);
  }
}
