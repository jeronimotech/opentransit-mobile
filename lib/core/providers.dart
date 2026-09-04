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
    this.poiLayer = false,
    this.bikeToStation = false,
    this.networkLayer = true,
    this.zonalLayer = false,
    this.rentalLayer = true,
  });
  final String? cityId;

  /// `null` follows the device locale.
  final Locale? locale;
  final ThemeMode themeMode;
  final bool wheelchair;
  final int maxWalkDistance;
  final bool liveVehicles;
  final bool poiLayer;
  final bool bikeToStation;
  final bool networkLayer;
  final bool zonalLayer;
  final bool rentalLayer;

  AppSettings copyWith({
    String? cityId,
    bool clearCity = false,
    Locale? locale,
    bool clearLocale = false,
    ThemeMode? themeMode,
    bool? wheelchair,
    int? maxWalkDistance,
    bool? liveVehicles,
    bool? poiLayer,
    bool? bikeToStation,
    bool? networkLayer,
    bool? zonalLayer,
    bool? rentalLayer,
  }) =>
      AppSettings(
        cityId: clearCity ? null : (cityId ?? this.cityId),
        locale: clearLocale ? null : (locale ?? this.locale),
        themeMode: themeMode ?? this.themeMode,
        wheelchair: wheelchair ?? this.wheelchair,
        maxWalkDistance: maxWalkDistance ?? this.maxWalkDistance,
        liveVehicles: liveVehicles ?? this.liveVehicles,
        poiLayer: poiLayer ?? this.poiLayer,
        bikeToStation: bikeToStation ?? this.bikeToStation,
        networkLayer: networkLayer ?? this.networkLayer,
        zonalLayer: zonalLayer ?? this.zonalLayer,
        rentalLayer: rentalLayer ?? this.rentalLayer,
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
      poiLayer: p.poiLayer,
      bikeToStation: p.bikeToStation,
      networkLayer: p.networkLayer,
      zonalLayer: p.zonalLayer,
      rentalLayer: p.rentalLayer,
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

  Future<void> setPoiLayer(bool v) async {
    state = state.copyWith(poiLayer: v);
    await _p.setPoiLayer(v);
  }

  Future<void> setBikeToStation(bool v) async {
    state = state.copyWith(bikeToStation: v);
    await _p.setBikeToStation(v);
  }

  Future<void> setNetworkLayer(bool v) async {
    state = state.copyWith(networkLayer: v);
    await _p.setNetworkLayer(v);
  }

  Future<void> setZonalLayer(bool v) async {
    state = state.copyWith(zonalLayer: v);
    await _p.setZonalLayer(v);
  }

  Future<void> setRentalLayer(bool v) async {
    state = state.copyWith(rentalLayer: v);
    await _p.setRentalLayer(v);
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

/// The selected city once loaded (null before the first load).
final currentCityProvider = Provider<City?>((ref) {
  final id = ref.watch(settingsProvider).cityId;
  if (id == null) return null;
  return ref.watch(cityProvider(id)).asData?.value;
});

/// Feed health, refreshed every 30 s while watched; drives freshness labels.
final healthProvider = FutureProvider.autoDispose.family<CityHealth, String>((ref, cityId) {
  final timer = Timer(const Duration(seconds: 30), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  return ref.watch(apiClientProvider).health(cityId);
});

// ───────────────────────── favorites / recents / alerts bookkeeping ─────────────────────────

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

  /// Adds or replaces (same key) — used for Casa/Trabajo which are singletons.
  Future<void> put(Favorite f) async {
    state = [...state.where((x) => x.key != f.key), f];
    await FavoritesRepository(ref.read(sharedPrefsProvider)).save(state);
  }

  Future<void> remove(Favorite f) async {
    state = state.where((x) => x.key != f.key).toList();
    await FavoritesRepository(ref.read(sharedPrefsProvider)).save(state);
  }

  Favorite? ofKind(String cityId, FavoriteKind kind) => state
      .where((f) => f.cityId == cityId && f.type == FavoriteType.place && f.kind == kind)
      .firstOrNull;
}

final favoritesProvider =
    NotifierProvider<FavoritesNotifier, List<Favorite>>(FavoritesNotifier.new);

class RecentTripsNotifier extends Notifier<List<RecentTrip>> {
  RecentTripsRepository get _repo => RecentTripsRepository(ref.read(sharedPrefsProvider));

  @override
  List<RecentTrip> build() => RecentTripsRepository(ref.watch(sharedPrefsProvider)).load();

  Future<void> add(RecentTrip t) async {
    state = _repo.push(state, t);
    await _repo.save(state);
  }

  Future<void> clear(String cityId) async {
    state = state.where((t) => t.cityId != cityId).toList();
    await _repo.save(state);
  }
}

final recentTripsProvider =
    NotifierProvider<RecentTripsNotifier, List<RecentTrip>>(RecentTripsNotifier.new);

/// Alert ids hidden from the Home carousel (dismissed or over the cap).
class AlertImpressionsNotifier extends Notifier<Set<String>> {
  AlertImpressionsRepository get _repo => AlertImpressionsRepository(ref.read(sharedPrefsProvider));

  @override
  Set<String> build() => {};

  bool shouldShow(String id) => !state.contains(id) && _repo.shouldShow(id);

  Future<void> dismiss(String id) async {
    state = {...state, id};
    await _repo.dismiss(id);
  }

  /// Counts one impression per alert per app session.
  final Set<String> _counted = {};
  Future<void> recordImpression(String id) async {
    if (!_counted.add(id)) return;
    await _repo.recordImpression(id);
  }
}

final alertImpressionsProvider =
    NotifierProvider<AlertImpressionsNotifier, Set<String>>(AlertImpressionsNotifier.new);

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

class StopRouteKey {
  const StopRouteKey(this.cityId, this.stopId, this.routeId);
  final String cityId;
  final String stopId;
  final String routeId;
  @override
  bool operator ==(Object other) =>
      other is StopRouteKey && other.cityId == cityId && other.stopId == stopId && other.routeId == routeId;
  @override
  int get hashCode => Object.hash(cityId, stopId, routeId);
}

/// Refresh cadence for departures/boards, from the city's remote config.
Duration _refreshFor(Ref ref, String cityId) {
  final c = ref.read(cityProvider(cityId)).asData?.value;
  return Duration(seconds: (c?.config.departuresRefreshSeconds ?? 20).clamp(5, 300));
}

final stopDetailProvider = FutureProvider.autoDispose.family<StopDetail, CityKey>(
    (ref, k) => ref.watch(apiClientProvider).stop(k.cityId, k.id));

final departuresProvider =
    FutureProvider.autoDispose.family<DeparturesResponse, CityKey>((ref, k) {
  final timer = Timer(_refreshFor(ref, k.cityId), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  return ref.watch(apiClientProvider).departures(k.cityId, k.id);
});

final boardProvider =
    FutureProvider.autoDispose.family<BoardResponse, CityKey>((ref, k) {
  final timer = Timer(_refreshFor(ref, k.cityId), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  return ref.watch(apiClientProvider).board(k.cityId, k.id);
});

final nextBusesProvider =
    FutureProvider.autoDispose.family<NextBusesResponse, StopRouteKey>((ref, k) {
  final timer = Timer(_refreshFor(ref, k.cityId), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  return ref.watch(apiClientProvider).nextBuses(k.cityId, k.stopId, k.routeId);
});

final routeDetailProvider = FutureProvider.autoDispose.family<RouteDetail, CityKey>(
    (ref, k) => ref.watch(apiClientProvider).route(k.cityId, k.id));

/// Simplified route shapes for the home map "Red" layer (cached per city).
final networkProvider = FutureProvider.family<List<NetworkShape>, String>(
    (ref, cityId) => ref.watch(apiClientProvider).network(cityId));

final routesProvider = FutureProvider.autoDispose.family<List<RouteRef>, String>(
    (ref, cityId) => ref.watch(apiClientProvider).routes(cityId));

final alertsProvider = FutureProvider.autoDispose.family<List<TransitAlert>, String>(
    (ref, cityId) => ref.watch(apiClientProvider).alerts(cityId));

final vehicleDetailProvider = FutureProvider.autoDispose.family<VehicleDetail, CityKey>(
    (ref, k) => ref.watch(apiClientProvider).vehicle(k.cityId, k.id));

class BboxQuery {
  BboxQuery(this.cityId, List<double> bbox, {this.types})
      : bbox = bbox.map((v) => (v * 1e3).round() / 1e3).toList(growable: false);
  final String cityId;
  final List<double> bbox;
  final List<String>? types;
  @override
  bool operator ==(Object other) =>
      other is BboxQuery &&
      other.cityId == cityId &&
      other.bbox.length == bbox.length &&
      other.bbox.indexed.every((e) => e.$2 == bbox[e.$1]) &&
      (other.types?.join(',') ?? '') == (types?.join(',') ?? '');
  @override
  int get hashCode => Object.hash(cityId, Object.hashAll(bbox), types?.join(','));
}

final poisProvider = FutureProvider.autoDispose.family<List<Poi>, BboxQuery>(
    (ref, q) => ref.watch(apiClientProvider).pois(q.cityId, q.bbox, types: q.types));

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

// ───────────────────────── v1.2 shared bikes ─────────────────────────

/// Networks with live counts/pricing (cached per city, refreshed every 5 min).
final rentalNetworksProvider =
    FutureProvider.autoDispose.family<List<BikeShareNetwork>, String>((ref, cityId) {
  final timer = Timer(const Duration(minutes: 5), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  ref.keepAlive();
  return ref.watch(apiClientProvider).rentalNetworks(cityId);
});

/// Docking stations inside a bbox, refreshed on the feed's TTL (30 s).
final rentalStationsProvider =
    FutureProvider.autoDispose.family<RentalStationsResponse, BboxQuery>((ref, q) async {
  final r = await ref.watch(apiClientProvider).rentalStations(q.cityId, bbox: q.bbox);
  final timer = Timer(Duration(seconds: r.ttlSeconds.clamp(15, 120)), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  return r;
});

final rentalStationProvider = FutureProvider.autoDispose.family<RentalStation, CityKey>((ref, k) {
  final timer = Timer(const Duration(seconds: 30), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  return ref.watch(apiClientProvider).rentalStation(k.cityId, k.id);
});

/// Nearest docking stations for the "Cerca de ti" strip.
final nearbyRentalProvider =
    FutureProvider.autoDispose.family<List<RentalStation>, NearbyQuery>((ref, q) {
  final timer = Timer(const Duration(seconds: 30), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  return ref.watch(apiClientProvider).nearbyRentalStations(q.cityId, LatLng(q.lat, q.lon),
      radiusMeters: q.radius, limit: 3);
});
