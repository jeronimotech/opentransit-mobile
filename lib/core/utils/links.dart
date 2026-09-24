import '../config.dart';
import '../models/models.dart';

/// Canonical `https://<web-host>/{city}/...` URLs shared by the web and mobile
/// apps (App Links / Universal Links). Also usable inside printed QR codes.
class CanonicalLinks {
  const CanonicalLinks._();

  /// The web host that serves a city: its own subdomain, unless the build
  /// pins every city to one host.
  static String hostFor(String cityId) =>
      AppConfig.webHost.isNotEmpty ? AppConfig.webHost : '$cityId.${AppConfig.webDomain}';

  /// Whether an incoming link belongs to this deployment. Any city subdomain
  /// counts, so a link from a city this build has never heard of still opens
  /// in the app instead of bouncing to the browser.
  static bool isOurHost(String host) {
    final h = host.toLowerCase();
    if (AppConfig.webHost.isNotEmpty && h == AppConfig.webHost.toLowerCase()) return true;
    final domain = AppConfig.webDomain.toLowerCase();
    return h == domain || h.endsWith('.$domain');
  }

  static Uri _u(String cityId, String path, [Map<String, String>? q]) => Uri(
        scheme: 'https',
        host: hostFor(cityId),
        path: path,
        queryParameters: q == null || q.isEmpty ? null : q,
      );

  static Uri city(String cityId) => _u(cityId, '/$cityId');
  static Uri stop(String cityId, String stopId) => _u(cityId, '/$cityId/stops/$stopId');
  static Uri route(String cityId, String routeId) => _u(cityId, '/$cityId/routes/$routeId');
  static Uri live(String cityId) => _u(cityId, '/$cityId/live');
  static Uri alerts(String cityId) => _u(cityId, '/$cityId/alerts');
  /// This app's own privacy policy. The agency's policy (`city.links.privacy`)
  /// describes the transit operator, not this app, so it cannot stand in for it.
  static Uri privacy(String cityId) => _u(cityId, '/$cityId/privacy');
  static Uri locate(String cityId, {String? stopId, String? routeId}) =>
      _u(cityId, '/$cityId/locate', {'stop': ?stopId, 'route': ?routeId});

  static Uri plan(String cityId, PlanRequest r) => _u(cityId, '/$cityId/plan', {
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
    if ((uri.scheme == 'https' || uri.scheme == 'http') && isOurHost(uri.host)) {
      return Uri(path: uri.path.isEmpty ? '/' : uri.path, queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters).toString();
    }
    return null;
  }
}
