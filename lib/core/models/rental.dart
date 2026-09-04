import 'common.dart';

/// A shared-mobility network configured for a city (v1.2 `city.mobility.bikeShare[]`),
/// optionally enriched by `/rental/networks` (system id, counts, pricing, health).
class BikeShareNetwork {
  const BikeShareNetwork({
    required this.id,
    required this.name,
    this.network,
    this.gbfsUrl,
    this.color = '#00A859',
    this.url,
    this.appIos,
    this.appAndroid,
    this.pricingSummary,
    this.formFactors = const ['bicycle'],
    this.systemId,
    this.timezone,
    this.stations,
    this.vehicleTypes = const [],
    this.pricingPlans = const [],
    this.lastFetchAt,
    this.up,
  });
  final String id;
  final String name;

  /// OTP updater network id.
  final String? network;
  final String? gbfsUrl;
  final String color;
  final String? url;
  final String? appIos;
  final String? appAndroid;
  final String? pricingSummary;

  /// `bicycle | scooter | ...`
  final List<String> formFactors;
  final String? systemId;
  final String? timezone;
  final int? stations;
  final List<RentalVehicleType> vehicleTypes;
  final List<RentalPricingPlan> pricingPlans;
  final DateTime? lastFetchAt;

  /// Null when unknown (city config only, no `/rental/networks` call yet).
  final bool? up;

  bool get hasScooters => formFactors.contains('scooter');

  factory BikeShareNetwork.fromJson(Map<String, dynamic> j) {
    final apps = j['apps'] is Map ? Map<String, dynamic>.from(j['apps'] as Map) : const <String, dynamic>{};
    return BikeShareNetwork(
      id: j['id'].toString(),
      name: j['name']?.toString() ?? j['id'].toString(),
      network: j['network']?.toString(),
      gbfsUrl: j['gbfsUrl']?.toString(),
      color: j['color']?.toString() ?? '#00A859',
      url: j['url']?.toString(),
      appIos: apps['ios']?.toString(),
      appAndroid: apps['android']?.toString(),
      pricingSummary: j['pricingSummary']?.toString(),
      formFactors: asStrings(j['formFactors']).isEmpty ? const ['bicycle'] : asStrings(j['formFactors']),
      systemId: j['systemId']?.toString(),
      timezone: j['timezone']?.toString(),
      stations: asInt(j['stations']),
      vehicleTypes: asList(j['vehicleTypes'], RentalVehicleType.fromJson),
      pricingPlans: asList(j['pricingPlans'], RentalPricingPlan.fromJson),
      lastFetchAt: parseTime(j['lastFetchAt']),
      up: j['up'] is bool ? j['up'] as bool : null,
    );
  }
}

class RentalVehicleType {
  const RentalVehicleType({required this.id, this.formFactor, this.propulsion, this.name, this.count});
  final String id;
  final String? formFactor;
  final String? propulsion;
  final String? name;

  /// Only on `vehicleTypesAvailable` of a station detail.
  final int? count;

  bool get isElectric => propulsion == 'electric_assist' || propulsion == 'electric';

  factory RentalVehicleType.fromJson(Map<String, dynamic> j) => RentalVehicleType(
        id: j['id'].toString(),
        formFactor: j['formFactor']?.toString(),
        propulsion: j['propulsion']?.toString(),
        name: j['name']?.toString(),
        count: asInt(j['count']),
      );
}

class RentalPricingPlan {
  const RentalPricingPlan({required this.id, required this.name, required this.price, required this.currency, this.description});
  final String id;
  final String name;
  final num price;
  final String currency;
  final String? description;

  factory RentalPricingPlan.fromJson(Map<String, dynamic> j) => RentalPricingPlan(
        id: j['id'].toString(),
        name: j['name']?.toString() ?? '',
        price: (j['price'] as num?) ?? 0,
        currency: j['currency']?.toString() ?? 'COP',
        description: j['description']?.toString(),
      );
}

/// A docking station of a shared-bike network with its live availability
/// (`/rental/stations`, `/stops/nearby?include=rental`, leg pickup/dropoff).
class RentalStation {
  const RentalStation({
    required this.id,
    this.networkId,
    required this.name,
    required this.position,
    this.capacity,
    this.vehiclesAvailable,
    this.ebikesAvailable,
    this.docksAvailable,
    this.isInstalled = true,
    this.isRenting = true,
    this.isReturning = true,
    this.lastReported,
    this.distanceMeters,
    this.vehicleTypesAvailable = const [],
    this.network,
  });
  final String id;
  final String? networkId;
  final String name;
  final LatLng position;
  final int? capacity;
  final int? vehiclesAvailable;
  final int? ebikesAvailable;
  final int? docksAvailable;
  final bool isInstalled;
  final bool isRenting;
  final bool isReturning;
  final DateTime? lastReported;

  /// Only set by nearby queries.
  final int? distanceMeters;
  final List<RentalVehicleType> vehicleTypesAvailable;

  /// Only set by the station detail endpoint.
  final BikeShareNetwork? network;

  /// Seconds since the station last reported, or null.
  int? ageSeconds({DateTime? now}) =>
      lastReported == null ? null : (now ?? DateTime.now()).difference(lastReported!).inSeconds.clamp(0, 1 << 30);

  bool get canRent => isInstalled && isRenting && (vehiclesAvailable ?? 0) > 0;
  bool get canReturn => isInstalled && isReturning && (docksAvailable ?? 0) > 0;

  RentalStation copyWith({int? distanceMeters}) => RentalStation(
        id: id, networkId: networkId, name: name, position: position, capacity: capacity,
        vehiclesAvailable: vehiclesAvailable, ebikesAvailable: ebikesAvailable, docksAvailable: docksAvailable,
        isInstalled: isInstalled, isRenting: isRenting, isReturning: isReturning, lastReported: lastReported,
        distanceMeters: distanceMeters ?? this.distanceMeters, vehicleTypesAvailable: vehicleTypesAvailable,
        network: network,
      );

  factory RentalStation.fromJson(Map<String, dynamic> j) => RentalStation(
        id: (j['id'] ?? j['stationId']).toString(),
        networkId: j['networkId']?.toString(),
        name: j['name']?.toString() ?? '',
        position: LatLng.fromJson(j),
        capacity: asInt(j['capacity']),
        vehiclesAvailable: asInt(j['vehiclesAvailable']),
        ebikesAvailable: asInt(j['ebikesAvailable']),
        docksAvailable: asInt(j['docksAvailable']),
        isInstalled: asBool(j['isInstalled'], fallback: true),
        isRenting: asBool(j['isRenting'], fallback: true),
        isReturning: asBool(j['isReturning'], fallback: true),
        lastReported: parseTime(j['lastReported']),
        distanceMeters: asInt(j['distanceMeters']),
        vehicleTypesAvailable: asList(j['vehicleTypesAvailable'], RentalVehicleType.fromJson),
        network: j['network'] is Map
            ? BikeShareNetwork.fromJson(Map<String, dynamic>.from(j['network'] as Map))
            : null,
      );
}

/// Rental price shown on a leg (`leg.rental.priceEstimate`).
class RentalPrice {
  const RentalPrice({required this.amount, required this.currency, this.label, this.estimated = true});
  final num amount;
  final String currency;
  final String? label;
  final bool estimated;

  factory RentalPrice.fromJson(Map<String, dynamic> j) => RentalPrice(
        amount: (j['amount'] as num?) ?? 0,
        currency: j['currency']?.toString() ?? 'COP',
        label: j['label']?.toString(),
        estimated: asBool(j['estimated'], fallback: true),
      );
}

/// Rental block attached to a `BICYCLE`/`SCOOTER` leg (v1.2 `leg.rental`).
class LegRental {
  const LegRental({
    required this.networkId,
    required this.networkName,
    this.color = '#00A859',
    this.vehicleType,
    this.pickup,
    this.dropoff,
    this.freeFloating = false,
    this.priceEstimate,
  });
  final String networkId;
  final String networkName;
  final String color;

  /// `bicycle | electric_assist | scooter | null`
  final String? vehicleType;
  final RentalStation? pickup;
  final RentalStation? dropoff;
  final bool freeFloating;
  final RentalPrice? priceEstimate;

  bool get isElectric => vehicleType == 'electric_assist' || vehicleType == 'electric';

  factory LegRental.fromJson(Map<String, dynamic> j) => LegRental(
        networkId: j['networkId']?.toString() ?? '',
        networkName: j['networkName']?.toString() ?? j['networkId']?.toString() ?? '',
        color: j['color']?.toString() ?? '#00A859',
        vehicleType: j['vehicleType']?.toString(),
        pickup: j['pickup'] is Map ? RentalStation.fromJson(Map<String, dynamic>.from(j['pickup'] as Map)) : null,
        dropoff: j['dropoff'] is Map ? RentalStation.fromJson(Map<String, dynamic>.from(j['dropoff'] as Map)) : null,
        freeFloating: asBool(j['freeFloating']),
        priceEstimate: j['priceEstimate'] is Map
            ? RentalPrice.fromJson(Map<String, dynamic>.from(j['priceEstimate'] as Map))
            : null,
      );
}

/// `/rental/stations` envelope.
class RentalStationsResponse {
  const RentalStationsResponse({required this.generatedAt, this.ttlSeconds = 30, required this.stations});
  final DateTime generatedAt;
  final int ttlSeconds;
  final List<RentalStation> stations;

  factory RentalStationsResponse.fromJson(Map<String, dynamic> j) => RentalStationsResponse(
        generatedAt: parseTime(j['generatedAt']) ?? DateTime.now(),
        ttlSeconds: asInt(j['ttlSeconds']) ?? 30,
        stations: asList(j['stations'], RentalStation.fromJson),
      );
}

/// `health.rental.networks[]`.
class RentalNetworkHealth {
  const RentalNetworkHealth({required this.id, this.up = true, this.stations, this.vehiclesAvailable, this.ageSeconds});
  final String id;
  final bool up;
  final int? stations;
  final int? vehiclesAvailable;
  final int? ageSeconds;

  factory RentalNetworkHealth.fromJson(Map<String, dynamic> j) => RentalNetworkHealth(
        id: j['id'].toString(),
        up: asBool(j['up'], fallback: true),
        stations: asInt(j['stations']),
        vehiclesAvailable: asInt(j['vehiclesAvailable']),
        ageSeconds: asInt(j['ageSeconds']),
      );
}
