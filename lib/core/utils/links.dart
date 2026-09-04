import '../config.dart';
import '../models/models.dart';

/// Canonical `https://<web-host>/{city}/...` URLs shared by the web and mobile
/// apps (App Links / Universal Links). Also usable inside printed QR codes.
class CanonicalLinks {
  const CanonicalLinks._();

  static Uri _u(String path, [Map<String, String>? q]) => Uri(
        scheme: 'https',
        host: AppConfig.webHost,
        path: path,
        queryParameters: q == null || q.isEmpty ? null : q,
      );

  static Uri city(String cityId) => _u('/$cityId');
  static Uri stop(String cityId, String stopId) => _u('/$cityId/stops/$stopId');
  static Uri route(String cityId, String routeId) => _u('/$cityId/routes/$routeId');
  static Uri live(String cityId) => _u('/$cityId/live');
  static Uri alerts(String cityId) => _u('/$cityId/alerts');
  static Uri locate(String cityId, {String? stopId, String? routeId}) =>
      _u('/$cityId/locate', {'stop': ?stopId, 'route': ?routeId});

  static Uri plan(String cityId, PlanRequest r) => _u('/$cityId/plan', {
        'fromLat': r.from.position.lat.toString(),
        'fromLon': r.from.position.lon.toString(),
        'toLat': r.to.position.lat.toString(),
        'toLon': r.to.position.lon.toString(),
        'fromName': r.from.name,
        'toName': r.to.name,
        if (r.time != null) 'time': r.time!.toIso8601String(),
        if (r.arriveBy) 'arriveBy': 'true',
      });

  /// Maps an incoming `https://<web-host>/…` or `opentransit://<city>/…` URI
  /// to an in-app location, or null when it is not ours.
  static String? toAppLocation(Uri uri) {
    if (uri.scheme == AppConfig.deepLinkScheme && uri.host.isNotEmpty) {
      return Uri(path: '/${uri.host}${uri.path}', queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters).toString();
    }
    if ((uri.scheme == 'https' || uri.scheme == 'http') && uri.host == AppConfig.webHost) {
      return Uri(path: uri.path.isEmpty ? '/' : uri.path, queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters).toString();
    }
    return null;
  }
}
