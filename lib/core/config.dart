import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Build-time configuration, driven by `--dart-define`.
///
/// * `API_URL`  base URL of opentransit-api (default: localhost / 10.0.2.2:8000)
/// * `MOCK`     `true` to use bundled fixtures instead of the network
/// * `MAP_STYLE` MapLibre style URL (default: OpenFreeMap "liberty")
class AppConfig {
  const AppConfig._();

  static const bool mock = bool.fromEnvironment('MOCK', defaultValue: false);

  static const String _apiUrlDefine = String.fromEnvironment('API_URL');

  static String get apiUrl {
    if (_apiUrlDefine.isNotEmpty) return _apiUrlDefine;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8001';
    return 'http://localhost:8001';
  }

  static const String mapStyle = String.fromEnvironment(
    'MAP_STYLE',
    defaultValue: 'https://tiles.openfreemap.org/styles/liberty',
  );

  static const String mapStyleDark = String.fromEnvironment(
    'MAP_STYLE_DARK',
    defaultValue: 'https://tiles.openfreemap.org/styles/dark',
  );

  /// This build's version.
  ///
  /// It was a hand-written constant and drifted six releases behind pubspec, so every
  /// build reported 1.8.0 and blocked itself the moment a minimum version was set
  /// above that. The release script now passes the real one; the default exists for
  /// `flutter run` and is pinned to pubspec by a test, because a value a human has to
  /// remember to edit is a value that will be wrong again.
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.14.2',
  );
  static const String deepLinkScheme = 'opentransit';

  /// Host of the web app whose `https://<host>/{city}/...` URLs this app
  /// claims (App Links / Universal Links) and emits when sharing. Keep in sync
  /// with `android/app/src/main/AndroidManifest.xml` and
  /// Identity used to build a store link when a city configured none. Both are
  /// build-time facts about *this* app, unlike the city's own update URL.
  static const String packageName = String.fromEnvironment(
    'PACKAGE_NAME',
    defaultValue: 'com.jeronimotech.opentransit',
  );
  static const String appStoreId = String.fromEnvironment(
    'APP_STORE_ID',
    defaultValue: '6809010622',
  );

  /// `ios/Runner/Runner.entitlements`.
  static const String webHost = String.fromEnvironment(
    'WEB_HOST',
    defaultValue: 'bogota.opentransit.tech',
  );
}
