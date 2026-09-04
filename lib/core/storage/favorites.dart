import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

enum FavoriteType { stop, route, place }

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

  factory Favorite.place(String cityId, Place p) => Favorite(
        type: FavoriteType.place,
        cityId: cityId,
        id: p.stopId ?? 'place:${p.position}',
        name: p.name,
        position: p.position,
        component: p.component,
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
