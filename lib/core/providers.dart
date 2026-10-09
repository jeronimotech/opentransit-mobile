import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io' show Platform;


import 'analytics/analytics.dart';
import 'analytics/analytics_event.dart';
import 'api/api_client.dart';
import 'api/http_api_client.dart';
import 'api/mock_api_client.dart';
import 'config.dart';
import 'city_icon.dart';
import 'connectivity.dart';
import 'utils/geo.dart';
import 'offline/city_cache.dart';
import 'offline/offline_board.dart';
import 'offline/offline_patterns.dart';
import 'offline/offline_plan.dart';
import 'offline/offline_segments.dart';
import 'offline/offline_router.dart';
import 'offline/offline_store.dart';
import 'models/models.dart';
import 'storage/favorites.dart';
import 'utils/notifications.dart';
import 'storage/scheduled_trips.dart';
import 'scheduling/trip_scheduler.dart';
import 'watch/watch_sync.dart';
import 'scheduling/push_registrar.dart';
import 'storage/preferences.dart';
import 'storage/route_alerts_store.dart';
import 'utils/commute.dart';
import 'utils/route_alerts.dart';

/// Overridden in `main()` once SharedPreferences is ready.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider must be overridden'),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => AppConfig.mock
      ? MockApiClient()
      : HttpApiClient(AppConfig.apiUrl,
          appVersion: AppConfig.appVersion,
          onStatus: (ok) => ref.read(connectionProvider.notifier).report(ok)),
);

// ───────────────────────── analytics (v1.5) ─────────────────────────

class _ApiTransport implements AnalyticsTransport {
  _ApiTransport(this._api);
  final ApiClient _api;
  @override
  Future<int> send(String cityId, Map<String, dynamic> batch) => _api.sendEvents(cityId, batch);
}

/// First-party analytics queue. City and locale are read lazily so the
/// service survives city changes; the opt-out lives in SharedPreferences.
final analyticsProvider = Provider<Analytics>((ref) {
  final a = Analytics(
    prefs: ref.watch(sharedPrefsProvider),
    transport: _ApiTransport(ref.watch(apiClientProvider)),
    cityId: () => ref.read(settingsProvider).cityId,
    locale: () => ref.read(settingsProvider).locale?.languageCode,
    platform: kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : 'ios'),
    appVersion: AppConfig.appVersion,
  );
  ref.onDispose(a.dispose);
  return a;
});

/// Mirrors the opt-out so widgets can rebuild when it changes.
class AnalyticsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(analyticsProvider).enabled;

  Future<void> set(bool v) async {
    state = v;
    await ref.read(analyticsProvider).setEnabled(v);
  }
}

final analyticsEnabledProvider = NotifierProvider<AnalyticsEnabledNotifier, bool>(AnalyticsEnabledNotifier.new);

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
    this.parkingLayer = true,
    this.guideSeen = false,
    this.dataSaver = false,
    this.backgroundGetOff = false,
    this.avoidStairs = false,
    this.strictWalkLimit = false,
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
  final bool parkingLayer;

  /// The first-open introduction has been shown.
  final bool guideSeen;

  /// Saver mode: fewer requests and no live vehicle stream. Opt-in.
  final bool dataSaver;

  /// The get-off alert may keep tracking with the screen locked. Opt-in, always.
  final bool backgroundGetOff;

  final bool avoidStairs;

  /// The walking limit is a limit, not a preference.
  final bool strictWalkLimit;

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
    bool? parkingLayer,
    bool? guideSeen,
    bool? dataSaver,
    bool? backgroundGetOff,
    bool? avoidStairs,
    bool? strictWalkLimit,
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
        parkingLayer: parkingLayer ?? this.parkingLayer,
        guideSeen: guideSeen ?? this.guideSeen,
        dataSaver: dataSaver ?? this.dataSaver,
        backgroundGetOff: backgroundGetOff ?? this.backgroundGetOff,
        avoidStairs: avoidStairs ?? this.avoidStairs,
        strictWalkLimit: strictWalkLimit ?? this.strictWalkLimit,
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
      parkingLayer: p.parkingLayer,
      guideSeen: p.guideSeen,
      dataSaver: p.dataSaver,
      backgroundGetOff: p.backgroundGetOff,
      avoidStairs: p.avoidStairs,
      strictWalkLimit: p.strictWalkLimit,
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
    ref.read(analyticsProvider).track(Ev.layerToggle, {'layer': 'liveVehicles', 'on': v});
    state = state.copyWith(liveVehicles: v);
    await _p.setLiveVehicles(v);
  }

  Future<void> setPoiLayer(bool v) async {
    ref.read(analyticsProvider).track(Ev.layerToggle, {'layer': 'pois', 'on': v});
    state = state.copyWith(poiLayer: v);
    await _p.setPoiLayer(v);
  }

  Future<void> setBikeToStation(bool v) async {
    state = state.copyWith(bikeToStation: v);
    await _p.setBikeToStation(v);
  }

  Future<void> setNetworkLayer(bool v) async {
    ref.read(analyticsProvider).track(Ev.layerToggle, {'layer': 'network', 'on': v});
    state = state.copyWith(networkLayer: v);
    await _p.setNetworkLayer(v);
  }

  Future<void> setZonalLayer(bool v) async {
    ref.read(analyticsProvider).track(Ev.layerToggle, {'layer': 'zonal', 'on': v});
    state = state.copyWith(zonalLayer: v);
    await _p.setZonalLayer(v);
  }

  Future<void> setRentalLayer(bool v) async {
    ref.read(analyticsProvider).track(Ev.layerToggle, {'layer': 'rental', 'on': v});
    state = state.copyWith(rentalLayer: v);
    await _p.setRentalLayer(v);
  }

  Future<void> setGuideSeen(bool v) async {
    state = state.copyWith(guideSeen: v);
    await _p.setGuideSeen(v);
  }

  Future<void> setDataSaver(bool v) async {
    state = state.copyWith(dataSaver: v);
    await _p.setDataSaver(v);
  }

  Future<void> setBackgroundGetOff(bool v) async {
    state = state.copyWith(backgroundGetOff: v);
    await _p.setBackgroundGetOff(v);
  }

  Future<void> setAvoidStairs(bool v) async {
    state = state.copyWith(avoidStairs: v);
    await _p.setAvoidStairs(v);
  }

  Future<void> setStrictWalkLimit(bool v) async {
    state = state.copyWith(strictWalkLimit: v);
    await _p.setStrictWalkLimit(v);
  }

  Future<void> setParkingLayer(bool v) async {
    ref.read(analyticsProvider).track(Ev.layerToggle, {'layer': 'parking', 'on': v});
    state = state.copyWith(parkingLayer: v);
    await _p.setParkingLayer(v);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

// ───────────────────────── cities ─────────────────────────

final cityCacheProvider = Provider<CityCache>((ref) => CityCache());

/// The city list, from the network when there is one and from disk when there is not.
///
/// The fallback is what makes everything else offline possible. Every screen needs its city's
/// configuration, so with only a network source the app sat on a spinner forever underground and a
/// rider could never reach the timetable they had downloaded on purpose. Found by pulling the
/// network on a real phone, not by any test here.
final citiesProvider = FutureProvider<List<City>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final cache = ref.watch(cityCacheProvider);
  try {
    final raw = await client.citiesRaw();
    if (raw == null) return await client.cities();
    // Written only on success, so a failed fetch never replaces a good copy with nothing.
    await cache.save(raw);
    return [for (final c in raw) City.fromJson(c)];
  } on Object {
    final cached = await cache.load();
    if (cached != null && cached.isNotEmpty) return cached;
    // Nothing cached either: a first run with no network is genuinely an error, and an error the
    // rider can retry beats a spinner that never resolves.
    rethrow;
  }
});

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
    final had = contains(f);
    final next = had
        ? state.where((x) => x.key != f.key).toList()
        : [...state, f];
    ref.read(analyticsProvider).track(had ? Ev.favoriteRemove : Ev.favoriteAdd, _favProps(f));
    state = next;
    await FavoritesRepository(ref.read(sharedPrefsProvider)).save(next);
  }

  /// Adds or replaces (same key) — used for Casa/Trabajo which are singletons.
  Future<void> put(Favorite f) async {
    ref.read(analyticsProvider).track(Ev.favoriteAdd, _favProps(f));
    state = [...state.where((x) => x.key != f.key), f];
    await FavoritesRepository(ref.read(sharedPrefsProvider)).save(state);
  }

  Future<void> remove(Favorite f) async {
    ref.read(analyticsProvider).track(Ev.favoriteRemove, _favProps(f));
    state = state.where((x) => x.key != f.key).toList();
    await FavoritesRepository(ref.read(sharedPrefsProvider)).save(state);
  }

  /// Only the kind (and the home/work label) is reported: never a custom
  /// name or address.
  static Map<String, Object?> _favProps(Favorite f) => {
        'kind': f.type.name,
        if (f.type == FavoriteType.place && (f.kind == FavoriteKind.home || f.kind == FavoriteKind.work))
          'label': f.kind.name,
      };

  Favorite? ofKind(String cityId, FavoriteKind kind) => state
      .where((f) => f.cityId == cityId && f.type == FavoriteType.place && f.kind == kind)
      .firstOrNull;
}

final favoritesProvider =
    NotifierProvider<FavoritesNotifier, List<Favorite>>(FavoritesNotifier.new);

/// v2.3 scheduled trips: stored on the device, reminders re-armed after every change.
final scheduledTripsProvider =
    NotifierProvider<ScheduledTripsNotifier, List<ScheduledTrip>>(ScheduledTripsNotifier.new);

class ScheduledTripsNotifier extends Notifier<List<ScheduledTrip>> {
  ScheduledTripsRepository get _repo => ScheduledTripsRepository(ref.read(sharedPrefsProvider));

  @override
  List<ScheduledTrip> build() => ScheduledTripsRepository(ref.watch(sharedPrefsProvider)).load();

  TripScheduler _scheduler() => TripScheduler(
        repo: _repo,
        api: ref.read(apiClientProvider),
        reminders: const LocalReminderSink(),
        jobs: const WorkmanagerJobs(),
        locale: ref.read(settingsProvider).locale ?? const Locale('es'),
      );

  Future<void> add(ScheduledTrip t) async {
    state = [...state.where((x) => x.id != t.id), t];
    await _repo.save(state);
    await resync();
  }

  Future<void> setEnabled(String id, bool enabled) async {
    state = [for (final t in state) t.id == id ? t.copyWith(enabled: enabled) : t];
    await _repo.save(state);
    await resync();
  }

  Future<void> remove(String id) async {
    for (final f in [eveId(id), leaveId(id), refineId(id)]) {
      await LocalNotifications.instance.cancel(f);
    }
    await const WorkmanagerJobs().cancelRefresh(id);
    state = state.where((t) => t.id != id).toList();
    await _repo.save(state);
  }

  /// Plans what is stale and re-arms every reminder. Safe to call often; only stale plans hit the
  /// network.
  Future<void> resync({bool replan = true}) async {
    try {
      state = await _scheduler().sync(now: DateTime.now(), replan: replan);
    } catch (e) {
      debugPrint('scheduled trips resync failed: $e');
    }
    await ref.read(pushRegistrarProvider).sync();
    await _syncWatch();
  }

  /// "Sales 7:12 · G30 → Trabajo" on the wrist, and its complication.
  Future<void> _syncWatch() async {
    final cityId = ref.read(settingsProvider).cityId;
    if (cityId == null) return;
    final next = nextScheduledTrip(state, DateTime.now());
    final city = ref.read(cityProvider(cityId)).asData?.value;
    try {
      await WatchSync.instance.syncNextTrip(
        cityId: cityId,
        cityName: city?.name ?? cityId,
        apiBaseUrl: AppConfig.apiUrl,
        nextTrip: next == null ? null : WatchNextTrip(leaveAt: next.leaveAt, arriveAt: next.arriveAt, toName: next.toName, routes: next.routes),
      );
    } catch (e) {
      debugPrint('watch next-trip sync failed: $e');
    }
  }
}

/// v2.3 — keeps the server's copy of this phone's wake instants and followed routes current (iOS
/// only; Android wakes itself). Also arms the Android alert poll while any route is followed.
final pushRegistrarProvider = Provider<PushRegistrarSync>((ref) => PushRegistrarSync(ref));

class PushRegistrarSync {
  PushRegistrarSync(this._ref);
  final Ref _ref;

  Future<void> sync() async {
    try {
      final settings = _ref.read(settingsProvider);
      final cityId = settings.cityId;
      if (cityId == null) return;
      final prefs = _ref.read(sharedPrefsProvider);
      final followed = RouteAlertsRepository(prefs).schedules(cityId).isNotEmpty;
      await const WorkmanagerJobs().ensureAlertPoll(followed);
      final city = _ref.read(cityProvider(cityId)).asData?.value;
      await PushRegistrar(prefs: prefs, api: _ref.read(apiClientProvider)).sync(
        cityId: cityId,
        serverReminders: city?.config.pushReminders ?? false,
        locale: settings.locale ?? const Locale('es'),
        now: DateTime.now(),
      );
    } catch (e) {
      debugPrint('push registrar sync failed: $e');
    }
  }
}

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

final routeAlertsRepositoryProvider = Provider<RouteAlertsRepository>(
    (ref) => RouteAlertsRepository(ref.watch(sharedPrefsProvider)));

/// Per-route alert schedules for the selected city, keyed by route id.
class RouteAlertSchedulesNotifier extends Notifier<Map<String, AlertSchedule>> {
  RouteAlertsRepository get _repo => ref.read(routeAlertsRepositoryProvider);

  @override
  Map<String, AlertSchedule> build() {
    final cityId = ref.watch(settingsProvider).cityId;
    return cityId == null ? const {} : _repo.schedules(cityId);
  }

  AlertSchedule of(String routeId) => state[routeId] ?? AlertSchedule.never;

  Future<void> set(String cityId, String routeId, AlertSchedule schedule) async {
    await _repo.setSchedule(cityId, routeId, schedule);
    state = _repo.schedules(cityId);
    await ref.read(pushRegistrarProvider).sync();
  }
}

final routeAlertSchedulesProvider =
    NotifierProvider<RouteAlertSchedulesNotifier, Map<String, AlertSchedule>>(
        RouteAlertSchedulesNotifier.new);

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
    FutureProvider.autoDispose.family<List<Stop>, NearbyQuery>((ref, q) async {
  try {
    return await ref
        .watch(apiClientProvider)
        .nearbyStops(q.cityId, LatLng(q.lat, q.lon), radiusMeters: q.radius);
  } on Object {
    // Same fallback as the board, and for the same reason: without it the downloaded timetable is
    // readable and unreachable. The board worked offline and the home screen's list and map were
    // both empty, so there was no way to arrive at a board at all.
    final bundle = await ref.read(offlineBundleProvider(q.cityId).future);
    if (bundle == null) rethrow;
    return offlineNearbyStops(bundle.header, LatLng(q.lat, q.lon), radiusMeters: q.radius);
  }
});

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

class SegmentKey {
  const SegmentKey(this.cityId, this.from, this.to, {this.routeId});
  final String cityId;
  final String from;
  final String to;

  /// The route the itinerary already shows, left out of the answer.
  final String? routeId;
  @override
  bool operator ==(Object other) =>
      other is SegmentKey &&
      other.cityId == cityId &&
      other.from == from &&
      other.to == to &&
      other.routeId == routeId;
  @override
  int get hashCode => Object.hash(cityId, from, to, routeId);
}

class PatternKey {
  const PatternKey(this.cityId, this.routeId, this.patternId);
  final String cityId;
  final String routeId;
  final String? patternId;
  @override
  bool operator ==(Object other) =>
      other is PatternKey &&
      other.cityId == cityId &&
      other.routeId == routeId &&
      other.patternId == patternId;
  @override
  int get hashCode => Object.hash(cityId, routeId, patternId);
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

final stopDetailProvider =
    FutureProvider.autoDispose.family<StopDetail, CityKey>((ref, k) async {
  try {
    return await ref.watch(apiClientProvider).stop(k.cityId, k.id);
  } on Object {
    // Third link in the same chain: the board read offline and the stops listed offline, and
    // opening one still hung, because the page waits on the stop's own details before drawing
    // anything. A downloaded timetable has to be reachable at every step or it is reachable at none.
    final bundle = await ref.read(offlineBundleProvider(k.cityId).future);
    if (bundle == null) rethrow;
    final raw = k.id.contains(':') ? k.id.split(':').skip(1).join(':') : k.id;
    final detail = await bundle.stopDetail(raw, k.cityId);
    if (detail == null) rethrow;
    return detail;
  }
});

final departuresProvider =
    FutureProvider.autoDispose.family<DeparturesResponse, CityKey>((ref, k) {
  final timer = Timer(_refreshFor(ref, k.cityId), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  return ref.watch(apiClientProvider).departures(k.cityId, k.id);
});

/// The installed pattern index, parsed once and held: a journey search jumps around it in an order
/// nothing on disk can predict, and re-parsing per search would cost more than the search.
final offlinePatternsProvider = FutureProvider.family<OfflinePatterns?, String>(
    (ref, cityId) => ref.watch(offlineStoreProvider).openPatterns(cityId));

/// Walking links between stops, built once per city. O(stops²) in the worst case and 8 311 stops
/// squared is not something to do while someone waits for a plan.
final offlineFootpathsProvider =
    FutureProvider.family<List<List<({int stop, int minutes})>>, String>((ref, cityId) async {
  final patterns = await ref.watch(offlinePatternsProvider(cityId).future);
  final bundle = await ref.watch(offlineBundleProvider(cityId).future);
  if (patterns == null || bundle == null) return const [];
  return buildFootpaths(bundle.header, patterns.stops);
});

/// Plan a journey from the downloaded timetable. Null when this city has nothing installed, which
/// the caller turns back into the original network error — one a rider can retry beats a blank
/// result that reads as "no way to get there".
Future<PlanResponse?> offlinePlan(Ref ref, String cityId, PlanRequest req) async {
  final patterns = await ref.read(offlinePatternsProvider(cityId).future);
  final bundle = await ref.read(offlineBundleProvider(cityId).future);
  if (patterns == null || bundle == null) return null;

  final at = req.time ?? DateTime.now();
  final day = DateTime(at.year, at.month, at.day);
  final services = bundle.header.activeServices(day);
  if (services.isEmpty) return null;

  // The scan works in stop indices; the planner works in coordinates. Anything within a short walk
  // of either end is a candidate, because a rider stands on a street and not on a stop.
  Set<int> near(LatLng p) {
    final out = <int>{};
    for (var i = 0; i < patterns.stops.length; i++) {
      final hi = bundle.header.stopIndexById[patterns.stops[i]];
      if (hi == null) continue;
      if (haversineMeters(p, bundle.header.stops[hi].position) <= 600) out.add(i);
    }
    return out;
  }

  final journeys = planOffline(
    data: patterns,
    originStops: near(req.from.position),
    destinationStops: near(req.to.position),
    departAfterMinute: at.hour * 60 + at.minute,
    runningServices: services,
    footpaths: await ref.read(offlineFootpathsProvider(cityId).future),
  );
  if (journeys.isEmpty) return null;
  return offlinePlanResponse(
    data: patterns, header: bundle.header, journeys: journeys,
    from: req.from, to: req.to, serviceDay: day, cityId: cityId,
  );
}

/// Whether this city's pattern index is installed, for the settings row. A small file check, not
/// the parse — showing a row should not cost megabytes of JSON.
final offlinePatternsInstalledProvider = FutureProvider.family<bool, String>(
    (ref, cityId) => ref.watch(offlineStoreProvider).hasPatterns(cityId));

final cityIconProvider = Provider<CityIcon>((ref) => CityIcon());

/// Which city's icon is on the home screen, or null for the default one.
final currentCityIconProvider =
    FutureProvider<String?>((ref) => ref.watch(cityIconProvider).current());

/// One store for every city; the files are per city, the object is not.
final offlineStoreProvider = Provider<OfflineStore>((ref) => OfflineStore());

/// The installed bundle for a city, or null. Kept alive rather than autoDispose: reopening it
/// re-reads and re-parses a megabyte of header, and a rider underground will hit it repeatedly.
final offlineBundleProvider = FutureProvider.family<InstalledBundle?, String>(
    (ref, cityId) => ref.watch(offlineStoreProvider).open(cityId));

/// What is installed, for a settings screen. Separate from [offlineBundleProvider] so showing the
/// row costs a small file read rather than parsing the header.
final offlineMetaProvider = FutureProvider.family<OfflineMeta?, String>(
    (ref, cityId) => ref.watch(offlineStoreProvider).meta(cityId));

final boardProvider =
    FutureProvider.autoDispose.family<BoardResponse, CityKey>((ref, k) async {
  final timer = Timer(_refreshFor(ref, k.cityId), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  try {
    return await ref.watch(apiClientProvider).board(k.cityId, k.id);
  } on Object {
    // The request failed, which underground is the normal case rather than the exception. Fall back
    // to the downloaded timetable if there is one, and rethrow if there is not: an error the rider
    // can act on beats an empty board that looks like the end of service.
    final board = await _offlineBoard(ref, k);
    if (board == null) rethrow;
    return board;
  }
});

Future<BoardResponse?> _offlineBoard(Ref ref, CityKey k) async {
  final bundle = await ref.read(offlineBundleProvider(k.cityId).future);
  if (bundle == null) return null;
  // Stop ids are city-scoped on the wire and bare in the bundle, which is built from the feed.
  final raw = k.id.contains(':') ? k.id.split(':').skip(1).join(':') : k.id;
  final si = bundle.header.stopIndexById[raw];
  if (si == null) return null;
  final now = DateTime.now();
  return offlineBoard(
    header: bundle.header,
    stop: bundle.header.stops[si],
    departures: await bundle.departures(raw, at: now, limit: 30),
    cityId: k.cityId,
    at: now,
  );
}

final nextBusesProvider =
    FutureProvider.autoDispose.family<NextBusesResponse, StopRouteKey>((ref, k) {
  final timer = Timer(_refreshFor(ref, k.cityId), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  return ref.watch(apiClientProvider).nextBuses(k.cityId, k.stopId, k.routeId);
});

final routeDetailProvider = FutureProvider.autoDispose.family<RouteDetail, CityKey>(
    (ref, k) => ref.watch(apiClientProvider).route(k.cityId, k.id));

/// Other services running one leg's segment, so a rider can board whichever comes first. Falls back
/// to the downloaded pattern index, which answers the same question with the same rule.
final segmentServicesProvider =
    FutureProvider.autoDispose.family<SegmentServices, SegmentKey>((ref, k) async {
  try {
    return await ref
        .watch(apiClientProvider)
        .segmentServices(k.cityId, k.from, k.to, exclude: k.routeId);
  } on Object {
    final offline = await _offlineSegments(ref, k);
    if (offline == null) rethrow;
    return offline;
  }
});

Future<SegmentServices?> _offlineSegments(Ref ref, SegmentKey k) async {
  final bundle = await ref.read(offlineBundleProvider(k.cityId).future);
  final patterns = await ref.read(offlinePatternsProvider(k.cityId).future);
  if (bundle == null || patterns == null) return null;
  String raw(String id) => id.contains(':') ? id.split(':').skip(1).join(':') : id;
  return offlineSegmentServices(
    cityId: k.cityId,
    header: bundle.header,
    patterns: patterns,
    fromId: raw(k.from),
    toId: raw(k.to),
    excludeRouteId: k.routeId,
  );
}

/// What one direction of a route runs today, and what connects along it. Cached for the screen's
/// lifetime: it is a day's timetable, not a live value.
final routeScheduleProvider =
    FutureProvider.autoDispose.family<PatternSchedule, PatternKey>((ref, k) =>
        ref.watch(apiClientProvider).routeSchedule(k.cityId, k.routeId, pattern: k.patternId));

/// Simplified route shapes for the home map "Red" layer (cached per city).
final networkProvider = FutureProvider.family<List<NetworkShape>, String>(
    (ref, cityId) => ref.watch(apiClientProvider).network(cityId));

final routesProvider = FutureProvider.autoDispose.family<List<RouteRef>, String>(
    (ref, cityId) => ref.watch(apiClientProvider).routes(cityId));

final alertsProvider = FutureProvider.autoDispose.family<List<TransitAlert>, String>(
    (ref, cityId) => ref.watch(apiClientProvider).alerts(cityId));

/// A "Cuándo salir" query — the planner inputs that change the forecast.
class ForecastQuery {
  const ForecastQuery({
    required this.cityId,
    required this.from,
    required this.to,
    required this.modes,
    this.onDemand = false,
    this.windowMinutes = 90,
  });
  final String cityId;
  final Place from;
  final Place to;
  final Set<TravelMode> modes;
  final bool onDemand;
  final int windowMinutes;

  @override
  bool operator ==(Object other) =>
      other is ForecastQuery &&
      other.cityId == cityId &&
      other.from.position == from.position &&
      other.to.position == to.position &&
      other.onDemand == onDemand &&
      other.windowMinutes == windowMinutes &&
      other.modes.length == modes.length &&
      other.modes.containsAll(modes);
  @override
  int get hashCode => Object.hash(cityId, from.position, to.position, onDemand, windowMinutes,
      Object.hashAllUnordered(modes));
}

final forecastProvider =
    FutureProvider.autoDispose.family<ForecastResponse, ForecastQuery>((ref, q) {
  final settings = ref.read(settingsProvider);
  return ref.watch(apiClientProvider).planForecast(
        q.cityId,
        PlanRequest(
          from: q.from,
          to: q.to,
          modes: q.modes.toList(),
          wheelchair: settings.wheelchair,
          onDemand: q.onDemand,
          locale: settings.locale?.languageCode ?? 'es',
        ),
        windowMinutes: q.windowMinutes,
      );
});

/// One planned commute (Casa ⇄ Trabajo) for the Home card.
class CommuteQuery {
  const CommuteQuery(this.cityId, this.from, this.to, this.direction);
  final String cityId;
  final Place from;
  final Place to;
  final CommuteDirection direction;
  @override
  bool operator ==(Object other) =>
      other is CommuteQuery &&
      other.cityId == cityId &&
      other.direction == direction &&
      other.from.position == from.position &&
      other.to.position == to.position;
  @override
  int get hashCode => Object.hash(cityId, direction, from.position, to.position);
}

/// The next viable departure for the commute, refreshed every two minutes so
/// the countdown on the card stays honest without hammering the router.
final commutePlanProvider =
    FutureProvider.autoDispose.family<PlanResponse, CommuteQuery>((ref, q) {
  final timer = Timer(const Duration(minutes: 2), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  return ref.watch(apiClientProvider).plan(
        q.cityId,
        PlanRequest(from: q.from, to: q.to, numItineraries: 3),
      );
});

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

/// Live fleet inside a bbox — the "Cerca de mí" stream (contract v1.9).
///
/// Subscribing by bbox is what keeps this mode cheap: the radius, not the city,
/// decides the bandwidth. The key rounds the box (see [BboxQuery]) so ordinary
/// GPS jitter does not tear the subscription down and build it again.
final nearbyLiveVehiclesProvider =
    StreamProvider.autoDispose.family<VehicleFrame, BboxQuery>((ref, q) {
  final api = ref.watch(apiClientProvider);
  return _liveFrames(api, q.cityId, bbox: q.bbox);
});

/// Folds the SSE events into frames and reconnects, with a subscription the
/// caller can actually end.
///
/// This was an `async*` generator with `await for` inside a retry loop, which
/// leaks: cancelling such a generator only takes effect at its next `yield`, so
/// while the feed is quiet — a stalled connection, or Bogotá after the last
/// service — the upstream subscription stays open forever after the screen is
/// gone. Owning the subscription explicitly makes cancellation immediate and
/// deterministic, which is the whole battery story of the live map.
Stream<VehicleFrame> _liveFrames(ApiClient api, String cityId, {List<double>? bbox}) {
  VehicleFrame? frame;
  StreamSubscription<Map<String, dynamic>>? sub;
  Timer? retry;
  var closed = false;
  late StreamController<VehicleFrame> out;

  void connect() {
    if (closed) return;
    sub = api.vehicleEvents(cityId, bbox: bbox).listen(
      (event) {
        frame = frame == null ? VehicleFrame.fromJson(event) : frame!.apply(event);
        if (!out.isClosed) out.add(frame!);
      },
      onError: (Object e, StackTrace st) {
        // Keep the last good frame rather than flickering the map empty; only
        // a failure before the first frame is worth surfacing.
        if (frame == null && !out.isClosed) out.addError(e, st);
      },
      onDone: () {
        sub = null;
        if (closed) return;
        retry = Timer(const Duration(seconds: 5), connect);
      },
      cancelOnError: false,
    );
  }

  out = StreamController<VehicleFrame>(
    onListen: connect,
    onCancel: () async {
      closed = true;
      retry?.cancel();
      final s = sub;
      sub = null;
      await s?.cancel();
    },
  );
  return out.stream;
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

/// v1.6 — paid parking zones in the viewport. PIM's counts are hours old, so a
/// minute between refreshes loses nothing.
final curbsProvider = FutureProvider.autoDispose.family<List<CurbZone>, BboxQuery>((ref, q) async {
  final zones = await ref.watch(apiClientProvider).curbs(q.cityId, bbox: q.bbox);
  final timer = Timer(const Duration(seconds: 60), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  return zones;
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
