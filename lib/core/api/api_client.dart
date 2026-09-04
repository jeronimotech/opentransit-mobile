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

  @override
  String toString() => 'ApiException($code, $status): $message';
}

/// Contract-level client. Both the HTTP implementation and the fixture-backed
/// mock implement this, so every feature depends only on this interface.
abstract class ApiClient {
  Future<List<City>> cities();
  Future<City> city(String cityId);

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

  Future<List<RouteRef>> routes(String cityId, {Component? component, String? query});
  Future<RouteDetail> route(String cityId, String routeId);
  Future<List<NetworkShape>> network(String cityId);

  Future<VehicleFrame> vehicles(String cityId, {String? routeId, List<double>? bbox});

  /// Raw SSE events (`{"type": "full" | "delta", ...}`); fold them with
  /// [VehicleFrame.apply].
  Stream<Map<String, dynamic>> vehicleEvents(String cityId);
  Future<VehicleDetail> vehicle(String cityId, String vehicleId);

  Future<List<TransitAlert>> alerts(
    String cityId, {
    String? routeId,
    String? stopId,
    bool active = true,
  });
}
