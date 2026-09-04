import '../models/models.dart';

/// Error surfaced by the API layer. `code` mirrors the contract error codes
/// (`CITY_NOT_FOUND`, `ROUTER_UNAVAILABLE`, ...) or `NETWORK` when the request
/// never reached the server.
class ApiException implements Exception {
  const ApiException(this.code, this.message, {this.status});
  final String code;
  final String message;
  final int? status;

  bool get isNetwork => code == 'NETWORK';

  /// 404 on a resource that exists only in newer API versions.
  bool get isNotFound => status == 404;

  @override
  String toString() => 'ApiException($code, $status): $message';
}

/// Contract-level client (v1 + v1.1). Both the HTTP implementation and the
/// fixture-backed mock implement this, so every feature depends only on this
/// interface.
abstract class ApiClient {
  Future<List<City>> cities();
  Future<City> city(String cityId);
  Future<CityHealth> health(String cityId);

  Future<PlanResponse> plan(String cityId, PlanRequest request);

  Future<List<GeocodeResult>> geocode(
    String cityId,
    String query, {
    LatLng? near,
    int limit = 8,
  });
  Future<Place> reverse(String cityId, LatLng position);

  Future<List<Stop>> nearbyStops(
    String cityId,
    LatLng position, {
    int radiusMeters = 500,
    int limit = 30,
  });
  Future<StopDetail> stop(String cityId, String stopId);
  Future<DeparturesResponse> departures(
    String cityId,
    String stopId, {
    int limit = 20,
    int minutes = 60,
  });

  /// v1.1 — arrival board grouped by route. Implementations fall back to
  /// grouping [departures] when the endpoint is missing.
  Future<BoardResponse> board(
    String cityId,
    String stopId, {
    int minutes = 60,
    int perRoute = 3,
  });

  /// v1.1 — "Ubica tu bus": next buses of one route at one stop.
  Future<NextBusesResponse> nextBuses(
    String cityId,
    String stopId,
    String routeId, {
    int limit = 3,
  });

  Future<List<RouteRef>> routes(String cityId, {Component? component, String? query});
  Future<RouteDetail> route(String cityId, String routeId);
  Future<List<NetworkShape>> network(String cityId);

  /// v1.1 — points of interest inside [bbox] (`minLon,minLat,maxLon,maxLat`).
  Future<List<Poi>> pois(String cityId, List<double> bbox, {List<String>? types});

  Future<VehicleFrame> vehicles(String cityId, {String? routeId, List<double>? bbox});

  /// Raw SSE events (`{"type": "full" | "delta", ...}`); fold them with
  /// [VehicleFrame.apply]. Filters are applied server-side when supported.
  Stream<Map<String, dynamic>> vehicleEvents(
    String cityId, {
    List<double>? bbox,
    List<String>? routeIds,
  });
  Future<VehicleDetail> vehicle(String cityId, String vehicleId);

  Future<List<TransitAlert>> alerts(
    String cityId, {
    String? routeId,
    String? stopId,
    bool active = true,
  });

  // ── v1.2 shared bikes (GBFS) ──

  /// Networks configured for the city, enriched with live counts and pricing.
  /// Empty (never an error) when the API predates v1.2.
  Future<List<BikeShareNetwork>> rentalNetworks(String cityId);

  /// Docking stations with live availability inside [bbox]
  /// (`minLon,minLat,maxLon,maxLat`).
  Future<RentalStationsResponse> rentalStations(
    String cityId, {
    List<double>? bbox,
    String? networkId,
    int limit = 500,
  });

  Future<RentalStation> rentalStation(String cityId, String stationId);

  /// Nearest docking stations, sorted by distance.
  Future<List<RentalStation>> nearbyRentalStations(
    String cityId,
    LatLng position, {
    int radiusMeters = 800,
    int limit = 5,
  });
}
