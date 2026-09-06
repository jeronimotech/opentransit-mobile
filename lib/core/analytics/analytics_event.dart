/// One first-party analytics event (CONTRACT-analytics v1.5).
///
/// Props are plain JSON values. Coordinates are coarsened before an event
/// enters the queue (see [coarsenProps]); nothing here is ever personal.
class AnalyticsEvent {
  AnalyticsEvent({required this.type, required this.at, Map<String, Object?> props = const {}})
      : props = Map.unmodifiable(props);
  final String type;
  final DateTime at;
  final Map<String, Object?> props;

  Map<String, dynamic> toJson() => {
        'type': type,
        'at': at.toIso8601String(),
        'props': props,
      };

  static AnalyticsEvent? fromJson(Object? j) {
    if (j is! Map) return null;
    final type = j['type']?.toString();
    final at = DateTime.tryParse(j['at']?.toString() ?? '');
    if (type == null || at == null) return null;
    final raw = j['props'];
    return AnalyticsEvent(
      type: type,
      at: at,
      props: raw is Map ? Map<String, Object?>.from(raw) : const {},
    );
  }
}

/// Rounds every coordinate-like prop to 3 decimals (≈ 110 m) and drops
/// nulls, so raw positions never leave the device.
Map<String, Object?> coarsenProps(Map<String, Object?> props) {
  final out = <String, Object?>{};
  for (final e in props.entries) {
    final v = e.value;
    if (v == null) continue;
    if (v is num && _isCoordinateKey(e.key)) {
      out[e.key] = (v * 1000).round() / 1000;
    } else {
      out[e.key] = v;
    }
  }
  return out;
}

bool _isCoordinateKey(String k) {
  final lower = k.toLowerCase();
  return lower == 'lat' || lower == 'lon' || lower.endsWith('lat') || lower.endsWith('lon');
}

/// Event type names, kept in one place so call sites and tests agree.
abstract final class Ev {
  static const appOpen = 'app_open';
  static const screenView = 'screen_view';
  static const searchSelect = 'search_select';
  static const planRequest = 'plan_request';
  static const planResult = 'plan_result';
  static const itinerarySelect = 'itinerary_select';
  static const goStart = 'go_start';
  static const goEnd = 'go_end';
  static const stopView = 'stop_view';
  static const boardView = 'board_view';
  static const routeView = 'route_view';
  static const locateQuery = 'locate_query';
  static const handoff = 'handoff';
  static const rentalStationView = 'rental_station_view';
  static const favoriteAdd = 'favorite_add';
  static const favoriteRemove = 'favorite_remove';
  static const alertView = 'alert_view';
  static const layerToggle = 'layer_toggle';
  static const modeToggle = 'mode_toggle';
  static const error = 'error';
}
