import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

enum FavoriteType { stop, route, place }

/// Typed places: Casa / Trabajo / custom icon (Maas-style).
enum FavoriteKind {
  home,
  work,
  custom;

  static FavoriteKind parse(Object? v) => switch (v?.toString()) {
        'home' => home,
        'work' => work,
        _ => custom,
      };
}

class Favorite {
  const Favorite({
    required this.type,
    required this.cityId,
    required this.id,
    required this.name,
    this.subtitle,
    this.position,
    this.color,
    this.component,
    this.kind = FavoriteKind.custom,
    this.icon,
  });
  final FavoriteType type;
  final String cityId;

  /// stopId / routeId / synthetic id for places (`place:<lat>,<lon>`).
  final String id;
  final String name;
  final String? subtitle;
  final LatLng? position;
  final String? color;
  final Component? component;

  /// Only meaningful for places.
  final FavoriteKind kind;

  /// Material icon name for custom places (`star`, `school`, `fitness_center`, ...).
  final String? icon;

  String get key => '${type.name}:$cityId:$id';

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'cityId': cityId,
        'id': id,
        'name': name,
        'subtitle': subtitle,
        'lat': position?.lat,
        'lon': position?.lon,
        'color': color,
        'component': component?.name,
        'kind': kind.name,
        'icon': icon,
      };

  factory Favorite.fromJson(Map<String, dynamic> j) => Favorite(
        type: FavoriteType.values.firstWhere((t) => t.name == j['type'],
            orElse: () => FavoriteType.place),
        cityId: j['cityId'].toString(),
        id: j['id'].toString(),
        name: j['name']?.toString() ?? '',
        subtitle: j['subtitle']?.toString(),
        position: j['lat'] != null && j['lon'] != null
            ? LatLng(asDouble(j['lat'])!, asDouble(j['lon'])!)
            : null,
        color: j['color']?.toString(),
        component: Component.parse(j['component']),
        kind: FavoriteKind.parse(j['kind']),
        icon: j['icon']?.toString(),
      );

  factory Favorite.stop(String cityId, Stop s) => Favorite(
        type: FavoriteType.stop,
        cityId: cityId,
        id: s.id,
        name: s.name,
        subtitle: s.code,
        position: s.position,
        component: s.component,
      );

  factory Favorite.route(String cityId, RouteRef r) => Favorite(
        type: FavoriteType.route,
        cityId: cityId,
        id: r.id,
        name: r.shortName,
        subtitle: r.longName,
        color: r.color,
        component: r.component,
      );

  factory Favorite.place(String cityId, Place p,
          {FavoriteKind kind = FavoriteKind.custom, String? icon, String? name}) =>
      Favorite(
        type: FavoriteType.place,
        cityId: cityId,
        // Home/Work are singletons per city so re-setting them replaces.
        id: kind == FavoriteKind.custom ? (p.stopId ?? 'place:${p.position}') : 'kind:${kind.name}',
        name: name ?? p.name,
        subtitle: kind == FavoriteKind.custom ? null : p.name,
        position: p.position,
        component: p.component,
        kind: kind,
        icon: icon,
      );

  Favorite copyWith({String? name, FavoriteKind? kind, String? icon}) => Favorite(
        type: type, cityId: cityId, id: id, name: name ?? this.name, subtitle: subtitle,
        position: position, color: color, component: component,
        kind: kind ?? this.kind, icon: icon ?? this.icon,
      );

  Place toPlace() => Place(
        name: name,
        position: position ?? const LatLng(0, 0),
        stopId: type == FavoriteType.stop ? id : null,
        component: component,
      );
}

/// Persists favorites as a JSON list in [SharedPreferences].
class FavoritesRepository {
  FavoritesRepository(this._prefs);
  final SharedPreferences _prefs;
  static const _key = 'favorites.v1';

  List<Favorite> load() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((e) => Favorite.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<Favorite> favorites) => _prefs.setString(
      _key, jsonEncode(favorites.map((f) => f.toJson()).toList()));
}

/// One origin/destination pair the user planned recently.
class RecentTrip {
  const RecentTrip({required this.cityId, required this.from, required this.to, required this.at});
  final String cityId;
  final Place from;
  final Place to;
  final DateTime at;

  String get key => '$cityId|${from.position}|${to.position}';

  Map<String, dynamic> toJson() => {
        'cityId': cityId,
        'from': _placeJson(from),
        'to': _placeJson(to),
        'at': at.toIso8601String(),
      };

  static Map<String, dynamic> _placeJson(Place p) => {
        'name': p.name, 'lat': p.position.lat, 'lon': p.position.lon,
        'stopId': p.stopId, 'component': p.component?.name,
      };

  factory RecentTrip.fromJson(Map<String, dynamic> j) => RecentTrip(
        cityId: j['cityId'].toString(),
        from: Place.fromJson(Map<String, dynamic>.from(j['from'] as Map)),
        to: Place.fromJson(Map<String, dynamic>.from(j['to'] as Map)),
        at: parseTime(j['at']) ?? DateTime.now(),
      );
}

/// Keeps the last [max] trips, most recent first, de-duplicated by O/D.
class RecentTripsRepository {
  RecentTripsRepository(this._prefs, {this.max = 10});
  final SharedPreferences _prefs;
  final int max;
  static const _key = 'recentTrips.v1';

  List<RecentTrip> load() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((e) => RecentTrip.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  List<RecentTrip> push(List<RecentTrip> current, RecentTrip trip) =>
      [trip, ...current.where((t) => t.key != trip.key)].take(max).toList();

  Future<void> save(List<RecentTrip> trips) =>
      _prefs.setString(_key, jsonEncode(trips.map((t) => t.toJson()).toList()));
}

/// Tracks how many times an alert was shown on Home and which were dismissed,
/// so the carousel caps impressions per alert id (TransMi-style).
class AlertImpressionsRepository {
  AlertImpressionsRepository(this._prefs, {this.maxImpressions = 3});
  final SharedPreferences _prefs;
  final int maxImpressions;
  static const _key = 'alertImpressions.v1';

  Map<String, dynamic> _load() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final m = jsonDecode(raw);
      return m is Map ? Map<String, dynamic>.from(m) : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _save(Map<String, dynamic> m) => _prefs.setString(_key, jsonEncode(m));

  int impressions(String id) => asInt((_load()[id] as Map?)?['n']) ?? 0;
  bool isDismissed(String id) => asBool((_load()[id] as Map?)?['dismissed']);

  /// Alerts that may still be shown: not dismissed and under the cap.
  bool shouldShow(String id) => !isDismissed(id) && impressions(id) < maxImpressions;

  Future<void> recordImpression(String id) async {
    final m = _load();
    final e = Map<String, dynamic>.from(m[id] as Map? ?? {});
    e['n'] = (asInt(e['n']) ?? 0) + 1;
    m[id] = e;
    await _save(m);
  }

  Future<void> dismiss(String id) async {
    final m = _load();
    final e = Map<String, dynamic>.from(m[id] as Map? ?? {});
    e['dismissed'] = true;
    m[id] = e;
    await _save(m);
  }

  /// Drops bookkeeping for alerts that no longer exist.
  Future<void> prune(Iterable<String> liveIds) async {
    final m = _load();
    final keep = liveIds.toSet();
    m.removeWhere((k, _) => !keep.contains(k));
    await _save(m);
  }
}
