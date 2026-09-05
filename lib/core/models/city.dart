import 'common.dart';
import 'ondemand.dart';
import 'rental.dart';

class CityAgency {
  const CityAgency({
    required this.id,
    required this.name,
    required this.component,
    required this.color,
  });
  final String id;
  final String name;
  final Component component;
  final String color;

  factory CityAgency.fromJson(Map<String, dynamic> j) => CityAgency(
        id: j['id'].toString(),
        name: j['name']?.toString() ?? '',
        component: Component.parse(j['component']) ?? Component.other,
        color: j['color']?.toString() ?? '#607D8B',
      );
}

class CityFeatures {
  const CityFeatures({
    this.realtimeVehicles = false,
    this.tripUpdates = false,
    this.alerts = false,
    this.fares = false,
    this.bikeShare = false,
    this.onDemand = false,
  });
  final bool realtimeVehicles;
  final bool tripUpdates;
  final bool alerts;
  final bool fares;
  final bool bikeShare;

  /// v1.4 taxi / ride-hailing options in the planner.
  final bool onDemand;

  factory CityFeatures.fromJson(Map<String, dynamic>? j) => j == null
      ? const CityFeatures()
      : CityFeatures(
          realtimeVehicles: asBool(j['realtimeVehicles']),
          tripUpdates: asBool(j['tripUpdates']),
          alerts: asBool(j['alerts']),
          fares: asBool(j['fares']),
          bikeShare: asBool(j['bikeShare']),
          onDemand: asBool(j['onDemand']),
        );
}

/// Display style for one transit component (v1.1 `city.components[]`).
class CityComponent {
  const CityComponent({
    required this.id,
    required this.label,
    required this.color,
    this.icon,
  });
  final Component id;
  final String label;
  final String color;

  /// `brt | bus | cable | rail | tram | other`
  final String? icon;

  factory CityComponent.fromJson(Map<String, dynamic> j) => CityComponent(
        id: Component.parse(j['id']) ?? Component.other,
        label: j['label']?.toString() ?? '',
        color: j['color']?.toString() ?? '#607D8B',
        icon: j['icon']?.toString(),
      );
}

/// Fare parameters used to *estimate* a fare when the GTFS has none.
class CityFares {
  const CityFares({
    required this.currency,
    required this.base,
    this.transfer = 0,
    this.transferWindowMinutes = 110,
    this.maxTransfers = 2,
    this.note,
    this.estimated = true,
  });
  final String currency;
  final num base;
  final num transfer;
  final int transferWindowMinutes;
  final int maxTransfers;
  final String? note;
  final bool estimated;

  factory CityFares.fromJson(Map<String, dynamic> j) => CityFares(
        currency: j['currency']?.toString() ?? 'COP',
        base: (j['base'] as num?) ?? 0,
        transfer: (j['transfer'] as num?) ?? 0,
        transferWindowMinutes: asInt(j['transferWindowMinutes']) ?? 110,
        maxTransfers: asInt(j['maxTransfers']) ?? 2,
        note: j['note']?.toString(),
        estimated: asBool(j['estimated'], fallback: true),
      );
}

class MaintenanceState {
  const MaintenanceState({this.active = false, this.message});
  final bool active;
  final String? message;

  factory MaintenanceState.fromJson(Map<String, dynamic>? j) => j == null
      ? const MaintenanceState()
      : MaintenanceState(
          active: asBool(j['active']),
          message: j['message']?.toString(),
        );
}

/// Remote configuration served with the city (v1.1 `city.config`).
class CityConfig {
  const CityConfig({
    this.vehiclePollSeconds = 15,
    this.departuresRefreshSeconds = 20,
    this.features = const {},
    this.minAppVersionIos,
    this.minAppVersionAndroid,
    this.maintenance = const MaintenanceState(),
  });
  final int vehiclePollSeconds;
  final int departuresRefreshSeconds;

  /// Module flags: `liveVehicles, board, pois, followAlong, bike`. Missing
  /// flags default to *enabled* so an older API never hides modules.
  final Map<String, bool> features;
  final String? minAppVersionIos;
  final String? minAppVersionAndroid;
  final MaintenanceState maintenance;

  bool isEnabled(String feature) => features[feature] ?? true;

  factory CityConfig.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const CityConfig();
    final min = j['minAppVersion'] is Map
        ? Map<String, dynamic>.from(j['minAppVersion'] as Map)
        : const <String, dynamic>{};
    final feats = j['features'] is Map
        ? Map<String, dynamic>.from(j['features'] as Map)
        : const <String, dynamic>{};
    return CityConfig(
      vehiclePollSeconds: asInt(j['vehiclePollSeconds']) ?? 15,
      departuresRefreshSeconds: asInt(j['departuresRefreshSeconds']) ?? 20,
      features: {for (final e in feats.entries) e.key: asBool(e.value, fallback: true)},
      minAppVersionIos: min['ios']?.toString(),
      minAppVersionAndroid: min['android']?.toString(),
      maintenance: MaintenanceState.fromJson(
        j['maintenance'] is Map
            ? Map<String, dynamic>.from(j['maintenance'] as Map)
            : null,
      ),
    );
  }
}

class CityLinks {
  const CityLinks({this.pqrs, this.recharge, this.support, this.privacy});
  final String? pqrs;
  final String? recharge;
  final String? support;
  final String? privacy;

  factory CityLinks.fromJson(Map<String, dynamic>? j) => j == null
      ? const CityLinks()
      : CityLinks(
          pqrs: j['pqrs']?.toString(),
          recharge: j['recharge']?.toString(),
          support: j['support']?.toString(),
          privacy: j['privacy']?.toString(),
        );
}

/// Partner hand-off tile (card recharge, parking, taxi...). Never core.
class CityService {
  const CityService({
    required this.id,
    required this.label,
    this.icon,
    required this.url,
    this.kind = 'external',
  });
  final String id;
  final String label;
  final String? icon;
  final String url;
  final String kind;

  factory CityService.fromJson(Map<String, dynamic> j) => CityService(
        id: j['id'].toString(),
        label: j['label']?.toString() ?? '',
        icon: j['icon']?.toString(),
        url: j['url']?.toString() ?? '',
        kind: j['kind']?.toString() ?? 'external',
      );
}

/// Shared-mobility networks and on-demand providers of a city
/// (v1.2 `city.mobility.bikeShare[]`, v1.4 `onDemand[]` / `taxiTariffs[]`).
class CityMobility {
  const CityMobility({
    this.bikeShare = const [],
    this.onDemand = const [],
    this.taxiTariffs = const [],
    this.onDemandPolicy = const OnDemandPolicy(),
  });
  final List<BikeShareNetwork> bikeShare;
  final List<OnDemandProvider> onDemand;
  final List<TaxiTariff> taxiTariffs;
  final OnDemandPolicy onDemandPolicy;

  bool get hasBikeShare => bikeShare.isNotEmpty;

  /// Enabled providers, in their configured order.
  List<OnDemandProvider> get onDemandProviders =>
      (onDemand.where((p) => p.enabled).toList()..sort((a, b) => a.order.compareTo(b.order)));
  bool get hasOnDemand => onDemandProviders.isNotEmpty;

  BikeShareNetwork? network(String? id) {
    if (id == null) return bikeShare.firstOrNull;
    for (final n in bikeShare) {
      if (n.id == id) return n;
    }
    return bikeShare.firstOrNull;
  }

  OnDemandProvider? provider(String? id) {
    if (id == null) return null;
    for (final p in onDemand) {
      if (p.id == id) return p;
    }
    return null;
  }

  TaxiTariff? tariff(String? id) {
    if (id == null) return taxiTariffs.firstOrNull;
    for (final t in taxiTariffs) {
      if (t.id == id) return t;
    }
    return taxiTariffs.firstOrNull;
  }

  factory CityMobility.fromJson(Map<String, dynamic>? j) => j == null
      ? const CityMobility()
      : CityMobility(
          bikeShare: asList(j['bikeShare'], BikeShareNetwork.fromJson),
          onDemand: asList(j['onDemand'], OnDemandProvider.fromJson),
          taxiTariffs: asList(j['taxiTariffs'], TaxiTariff.fromJson),
          onDemandPolicy: OnDemandPolicy.fromJson(
              j['onDemandPolicy'] is Map ? Map<String, dynamic>.from(j['onDemandPolicy'] as Map) : null),
        );
}

class City {
  const City({
    required this.id,
    required this.name,
    required this.country,
    required this.timezone,
    required this.locale,
    required this.center,
    required this.bbox,
    required this.defaultZoom,
    required this.modes,
    required this.primaryColor,
    this.logoUrl,
    required this.features,
    required this.agencies,
    required this.attribution,
    this.components = const [],
    this.fares,
    this.config = const CityConfig(),
    this.links = const CityLinks(),
    this.services = const [],
    this.mobility = const CityMobility(),
  });

  final String id;
  final String name;
  final String country;
  final String timezone;
  final String locale;
  final LatLng center;

  /// `[minLon, minLat, maxLon, maxLat]`
  final List<double> bbox;
  final double defaultZoom;
  final List<TravelMode> modes;
  final String primaryColor;
  final String? logoUrl;
  final CityFeatures features;
  final List<CityAgency> agencies;
  final String attribution;
  final List<CityComponent> components;
  final CityFares? fares;
  final CityConfig config;
  final CityLinks links;
  final List<CityService> services;
  final CityMobility mobility;

  /// Shared bikes are offered when the feature flag is on, the module is not
  /// disabled by remote config and at least one network is configured.
  bool get bikeShareEnabled =>
      features.bikeShare && config.isEnabled('bikeShare') && mobility.hasBikeShare;

  /// Taxi / ride-hailing options are offered when the feature flag is on, the
  /// module is not disabled by remote config and at least one provider is
  /// enabled (v1.4).
  bool get onDemandEnabled =>
      features.onDemand && config.isEnabled('onDemand') && mobility.hasOnDemand;

  factory City.fromJson(Map<String, dynamic> j) {
    final branding = j['branding'] is Map
        ? Map<String, dynamic>.from(j['branding'] as Map)
        : const <String, dynamic>{};
    return City(
      id: j['id'].toString(),
      name: j['name']?.toString() ?? j['id'].toString(),
      country: j['country']?.toString() ?? '',
      timezone: j['timezone']?.toString() ?? 'UTC',
      locale: j['locale']?.toString() ?? 'es',
      center: j['center'] is Map
          ? LatLng.fromJson(Map<String, dynamic>.from(j['center'] as Map))
          : const LatLng(0, 0),
      bbox: (j['bbox'] as List?)
              ?.map((e) => asDouble(e) ?? 0)
              .toList(growable: false) ??
          const [-180, -90, 180, 90],
      defaultZoom: asDouble(j['defaultZoom']) ?? 12,
      modes: asStrings(j['modes']).map(TravelMode.parse).toList(growable: false),
      primaryColor: branding['primaryColor']?.toString() ?? '#1565C0',
      logoUrl: branding['logoUrl']?.toString(),
      features: CityFeatures.fromJson(
        j['features'] is Map
            ? Map<String, dynamic>.from(j['features'] as Map)
            : null,
      ),
      agencies: asList(j['agencies'], CityAgency.fromJson),
      attribution: j['attribution']?.toString() ?? '',
      components: asList(j['components'], CityComponent.fromJson),
      fares: j['fares'] is Map
          ? CityFares.fromJson(Map<String, dynamic>.from(j['fares'] as Map))
          : null,
      config: CityConfig.fromJson(
        j['config'] is Map ? Map<String, dynamic>.from(j['config'] as Map) : null,
      ),
      links: CityLinks.fromJson(
        j['links'] is Map ? Map<String, dynamic>.from(j['links'] as Map) : null,
      ),
      services: asList(j['services'], CityService.fromJson),
      mobility: CityMobility.fromJson(
        j['mobility'] is Map ? Map<String, dynamic>.from(j['mobility'] as Map) : null,
      ),
    );
  }

  bool contains(LatLng p) =>
      bbox.length == 4 &&
      p.lon >= bbox[0] &&
      p.lat >= bbox[1] &&
      p.lon <= bbox[2] &&
      p.lat <= bbox[3];

  /// Component style from `components[]`, falling back to the agencies list.
  CityComponent? componentStyle(Component? c) {
    if (c == null) return null;
    for (final x in components) {
      if (x.id == c) return x;
    }
    for (final a in agencies) {
      if (a.component == c) {
        return CityComponent(id: c, label: a.name, color: a.color);
      }
    }
    return null;
  }
}
