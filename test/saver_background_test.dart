library;

/// Saver mode (1.15) and the get-off alert with the screen locked (1.6).
///
/// Both are rider-controlled switches, and the test that matters most for 1.6 is that it is off
/// until someone turns it on: continuous location is the most expensive thing this app can do to a
/// battery, and nobody should pay that by default.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:opentransit_mobile/core/providers.dart';
import 'package:opentransit_mobile/core/utils/refresh.dart';
import 'package:opentransit_mobile/core/utils/tracking_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

LocationSettings _settings({required bool background}) => trackingSettings(
      background: background,
      notificationTitle: 'opentransit',
      notificationText: 'Siguiendo tu viaje',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('refresh interval', () {
    test('follows the city, clamped', () {
      expect(refreshInterval(20).inSeconds, 20);
      expect(refreshInterval(null).inSeconds, 20);
      expect(refreshInterval(1).inSeconds, 5);
      expect(refreshInterval(9999).inSeconds, 300);
    });

    test('saver mode triples it without breaking the ceiling', () {
      expect(refreshInterval(20, saver: true).inSeconds, 60);
      expect(refreshInterval(120, saver: true).inSeconds, 300);
    });
  });

  group('tracking settings', () {
    test('the foreground trip asks for nothing special', () {
      final s = _settings(background: false);
      expect(s, isNot(isA<AndroidSettings>()));
      expect(s, isNot(isA<AppleSettings>()));
      expect(s.distanceFilter, 10);
    });

    test('on Android the background trip runs as a visible foreground service', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final s = _settings(background: true) as AndroidSettings;
      // The rider can see it running and stop it — which is why this is a foreground service and
      // not the background-location permission.
      expect(s.foregroundNotificationConfig, isNotNull);
      expect(s.foregroundNotificationConfig!.setOngoing, isTrue);
      expect(s.foregroundNotificationConfig!.notificationText, 'Siguiendo tu viaje');
    });

    test('on iOS the background trip keeps the indicator and does not let the system pause it', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final s = _settings(background: true) as AppleSettings;
      expect(s.allowBackgroundLocationUpdates, isTrue);
      expect(s.showBackgroundLocationIndicator, isTrue);
      // The system pauses updates when it decides the rider stopped moving, which on a bus in
      // traffic is exactly when the next stop is about to be theirs.
      expect(s.pauseLocationUpdatesAutomatically, isFalse);
    });
  });

  group('the switches', () {
    late ProviderContainer c;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'city': 'bogota'});
      prefs = await SharedPreferences.getInstance();
      c = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
    });
    tearDown(() => c.dispose());

    test('both are off until the rider turns them on', () {
      expect(c.read(settingsProvider).dataSaver, isFalse);
      expect(c.read(settingsProvider).backgroundGetOff, isFalse);
    });

    test('and they persist', () async {
      await c.read(settingsProvider.notifier).setDataSaver(true);
      await c.read(settingsProvider.notifier).setBackgroundGetOff(true);
      expect(prefs.getBool('dataSaver'), isTrue);
      expect(prefs.getBool('backgroundGetOff'), isTrue);
      expect(c.read(settingsProvider).dataSaver, isTrue);
      expect(c.read(settingsProvider).backgroundGetOff, isTrue);
    });
  });
}
