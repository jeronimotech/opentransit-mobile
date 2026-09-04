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

  static const String appVersion = '0.1.0';
  static const String deepLinkScheme = 'opentransit';
}
