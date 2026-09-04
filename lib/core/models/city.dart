import 'common.dart';

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
  });
  final bool realtimeVehicles;
  final bool tripUpdates;
  final bool alerts;
  final bool fares;
  final bool bikeShare;

  factory CityFeatures.fromJson(Map<String, dynamic>? j) => j == null
      ? const CityFeatures()
      : CityFeatures(
          realtimeVehicles: asBool(j['realtimeVehicles']),
          tripUpdates: asBool(j['tripUpdates']),
          alerts: asBool(j['alerts']),
          fares: asBool(j['fares']),
          bikeShare: asBool(j['bikeShare']),
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
    );
  }

  bool contains(LatLng p) =>
      bbox.length == 4 &&
      p.lon >= bbox[0] &&
      p.lat >= bbox[1] &&
      p.lon <= bbox[2] &&
      p.lat <= bbox[3];
}
