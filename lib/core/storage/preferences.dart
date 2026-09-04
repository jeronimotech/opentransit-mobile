import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

/// Thin typed wrapper over [SharedPreferences] for user settings.
class PreferencesRepository {
  PreferencesRepository(this._prefs);
  final SharedPreferences _prefs;

  static const _kCity = 'city';
  static const _kLocale = 'locale';
  static const _kTheme = 'theme';
  static const _kWheelchair = 'wheelchair';
  static const _kMaxWalk = 'maxWalk';
  static const _kLive = 'liveVehicles';
  static const _kPois = 'poiLayer';
  static const _kBike = 'bikeToStation';
  static const _kNetwork = 'networkLayer';

  String? get cityId => _prefs.getString(_kCity);
  Future<void> setCityId(String? id) =>
      id == null ? _prefs.remove(_kCity) : _prefs.setString(_kCity, id);

  String? get localeCode => _prefs.getString(_kLocale);
  Future<void> setLocaleCode(String? code) =>
      code == null ? _prefs.remove(_kLocale) : _prefs.setString(_kLocale, code);

  ThemeMode get themeMode => switch (_prefs.getString(_kTheme)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
  Future<void> setThemeMode(ThemeMode m) => _prefs.setString(_kTheme, m.name);

  bool get wheelchair => _prefs.getBool(_kWheelchair) ?? false;
  Future<void> setWheelchair(bool v) => _prefs.setBool(_kWheelchair, v);

  int get maxWalkDistance => _prefs.getInt(_kMaxWalk) ?? 1500;
  Future<void> setMaxWalkDistance(int m) => _prefs.setInt(_kMaxWalk, m);

  bool get liveVehicles => _prefs.getBool(_kLive) ?? true;
  Future<void> setLiveVehicles(bool v) => _prefs.setBool(_kLive, v);

  bool get poiLayer => _prefs.getBool(_kPois) ?? false;
  Future<void> setPoiLayer(bool v) => _prefs.setBool(_kPois, v);

  bool get bikeToStation => _prefs.getBool(_kBike) ?? false;
  Future<void> setBikeToStation(bool v) => _prefs.setBool(_kBike, v);

  /// Route shapes on the home map (default on, drawn from zoom 12).
  bool get networkLayer => _prefs.getBool(_kNetwork) ?? true;
  Future<void> setNetworkLayer(bool v) => _prefs.setBool(_kNetwork, v);
}
