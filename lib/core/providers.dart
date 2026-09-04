import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_client.dart';
import 'api/http_api_client.dart';
import 'api/mock_api_client.dart';
import 'config.dart';
import 'models/models.dart';
import 'storage/favorites.dart';
import 'storage/preferences.dart';

/// Overridden in `main()` once SharedPreferences is ready.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider must be overridden'),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => AppConfig.mock ? MockApiClient() : HttpApiClient(AppConfig.apiUrl),
);

final preferencesProvider = Provider<PreferencesRepository>(
  (ref) => PreferencesRepository(ref.watch(sharedPrefsProvider)),
);

// ───────────────────────── settings ─────────────────────────

class AppSettings {
  const AppSettings({
    this.cityId,
    this.locale,
    this.themeMode = ThemeMode.system,
    this.wheelchair = false,
    this.maxWalkDistance = 1500,
    this.liveVehicles = true,
  });
  final String? cityId;

  /// `null` follows the device locale.
  final Locale? locale;
  final ThemeMode themeMode;
  final bool wheelchair;
  final int maxWalkDistance;
  final bool liveVehicles;

  AppSettings copyWith({
    String? cityId,
    bool clearCity = false,
    Locale? locale,
    bool clearLocale = false,
    ThemeMode? themeMode,
    bool? wheelchair,
    int? maxWalkDistance,
    bool? liveVehicles,
  }) =>
      AppSettings(
        cityId: clearCity ? null : (cityId ?? this.cityId),
        locale: clearLocale ? null : (locale ?? this.locale),
        themeMode: themeMode ?? this.themeMode,
        wheelchair: wheelchair ?? this.wheelchair,
        maxWalkDistance: maxWalkDistance ?? this.maxWalkDistance,
        liveVehicles: liveVehicles ?? this.liveVehicles,
      );
}

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final p = ref.watch(preferencesProvider);
    final code = p.localeCode;
    return AppSettings(
      cityId: p.cityId,
      locale: code == null ? null : Locale(code),
      themeMode: p.themeMode,
      wheelchair: p.wheelchair,
      maxWalkDistance: p.maxWalkDistance,
      liveVehicles: p.liveVehicles,
    );
  }

  PreferencesRepository get _p => ref.read(preferencesProvider);

  Future<void> setCity(String? id) async {
    state = state.copyWith(cityId: id, clearCity: id == null);
    await _p.setCityId(id);
  }

  Future<void> setLocale(Locale? l) async {
    state = state.copyWith(locale: l, clearLocale: l == null);
    await _p.setLocaleCode(l?.languageCode);
  }

  Future<void> setThemeMode(ThemeMode m) async {
    state = state.copyWith(themeMode: m);
    await _p.setThemeMode(m);
  }

  Future<void> setWheelchair(bool v) async {
    state = state.copyWith(wheelchair: v);
    await _p.setWheelchair(v);
  }

  Future<void> setMaxWalkDistance(int m) async {
    state = state.copyWith(maxWalkDistance: m);
    await _p.setMaxWalkDistance(m);
  }

  Future<void> setLiveVehicles(bool v) async {
    state = state.copyWith(liveVehicles: v);
    await _p.setLiveVehicles(v);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

// ───────────────────────── cities ─────────────────────────

final citiesProvider = FutureProvider<List<City>>(
  (ref) => ref.watch(apiClientProvider).cities(),
);

final cityProvider = FutureProvider.family<City, String>((ref, id) async {
  final cached = ref.watch(citiesProvider).asData?.value;
  if (cached != null) {
    for (final c in cached) {
      if (c.id == id) return c;
    }
  }
  return ref.watch(apiClientProvider).city(id);
});

// ───────────────────────── favorites ─────────────────────────

class FavoritesNotifier extends Notifier<List<Favorite>> {
  @override
  List<Favorite> build() =>
      FavoritesRepository(ref.watch(sharedPrefsProvider)).load();

  bool contains(Favorite f) => state.any((x) => x.key == f.key);

  Future<void> toggle(Favorite f) async {
    final next = contains(f)
        ? state.where((x) => x.key != f.key).toList()
        : [...state, f];
    state = next;
    await FavoritesRepository(ref.read(sharedPrefsProvider)).save(next);
  }

  Future<void> remove(Favorite f) async {
    state = state.where((x) => x.key != f.key).toList();
    await FavoritesRepository(ref.read(sharedPrefsProvider)).save(state);
  }
}

final favoritesProvider =
    NotifierProvider<FavoritesNotifier, List<Favorite>>(FavoritesNotifier.new);

// ───────────────────────── data ─────────────────────────

class NearbyQuery {
  NearbyQuery(this.cityId, LatLng at, {this.radius = 600})
      : lat = (at.lat * 1e4).round() / 1e4,
        lon = (at.lon * 1e4).round() / 1e4;
  final String cityId;
  final double lat;
  final double lon;
  final int radius;

  @override
  bool operator ==(Object other) =>
      other is NearbyQuery &&
      other.cityId == cityId &&
      other.lat == lat &&
      other.lon == lon &&
      other.radius == radius;

  @override
  int get hashCode => Object.hash(cityId, lat, lon, radius);
}

final nearbyStopsProvider =
    FutureProvider.autoDispose.family<List<Stop>, NearbyQuery>((ref, q) =>
        ref.watch(apiClientProvider).nearbyStops(q.cityId, LatLng(q.lat, q.lon),
            radiusMeters: q.radius));

class CityKey {
  const CityKey(this.cityId, this.id);
  final String cityId;
  final String id;
  @override
  bool operator ==(Object other) =>
      other is CityKey && other.cityId == cityId && other.id == id;
  @override
  int get hashCode => Object.hash(cityId, id);
}

final stopDetailProvider = FutureProvider.autoDispose.family<StopDetail, CityKey>(
    (ref, k) => ref.watch(apiClientProvider).stop(k.cityId, k.id));

final departuresProvider =
    FutureProvider.autoDispose.family<DeparturesResponse, CityKey>((ref, k) {
  // Auto-refresh every 20 s while someone is listening.
  final timer = Timer(const Duration(seconds: 20), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  return ref.watch(apiClientProvider).departures(k.cityId, k.id);
});

final routeDetailProvider = FutureProvider.autoDispose.family<RouteDetail, CityKey>(
    (ref, k) => ref.watch(apiClientProvider).route(k.cityId, k.id));

final routesProvider = FutureProvider.autoDispose.family<List<RouteRef>, String>(
    (ref, cityId) => ref.watch(apiClientProvider).routes(cityId));

final alertsProvider = FutureProvider.autoDispose.family<List<TransitAlert>, String>(
    (ref, cityId) => ref.watch(apiClientProvider).alerts(cityId));

final vehicleDetailProvider = FutureProvider.autoDispose.family<VehicleDetail, CityKey>(
    (ref, k) => ref.watch(apiClientProvider).vehicle(k.cityId, k.id));

/// Live fleet for a city, folded from the SSE stream. Reconnects after 5 s on
/// error; the last good frame is kept so the map never flickers empty.
final liveVehiclesProvider =
    StreamProvider.autoDispose.family<VehicleFrame, String>((ref, cityId) {
  final api = ref.watch(apiClientProvider);
  return _liveFrames(api, cityId);
});

Stream<VehicleFrame> _liveFrames(ApiClient api, String cityId) async* {
  VehicleFrame? frame;
  while (true) {
    try {
      await for (final event in api.vehicleEvents(cityId)) {
        frame = frame == null ? VehicleFrame.fromJson(event) : frame.apply(event);
        yield frame;
      }
    } catch (e) {
      if (frame == null) yield* Stream<VehicleFrame>.error(e);
    }
    await Future<void>.delayed(const Duration(seconds: 5));
  }
}
