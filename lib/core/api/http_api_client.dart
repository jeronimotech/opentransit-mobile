import 'dart:async';

import 'package:dio/dio.dart';

import '../models/models.dart';
import 'api_client.dart';
import 'sse.dart';

/// Dio-backed implementation of the opentransit-api v1 contract.
class HttpApiClient implements ApiClient {
  HttpApiClient(String baseUrl, {Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 30),
              headers: const {'Accept': 'application/json'},
            ));

  final Dio _dio;

  String get baseUrl => _dio.options.baseUrl;

  String _c(String cityId) => '/v1/cities/${Uri.encodeComponent(cityId)}';

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final r = await _dio.get<dynamic>(path, queryParameters: query);
      final body = r.data;
      if (body is Map) return Map<String, dynamic>.from(body);
      throw ApiException('BAD_RESPONSE', 'Unexpected body for $path',
          status: r.statusCode);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  ApiException _toApiException(DioException e) {
    final body = e.response?.data;
    if (body is Map && body['error'] is Map) {
      final err = Map<String, dynamic>.from(body['error'] as Map);
      return ApiException(
        err['code']?.toString() ?? 'ERROR',
        err['message']?.toString() ?? e.message ?? 'Request failed',
        status: e.response?.statusCode,
      );
    }
    if (e.response != null) {
      return ApiException('HTTP_${e.response!.statusCode}',
          e.message ?? 'Request failed',
          status: e.response!.statusCode);
    }
    return ApiException('NETWORK', e.message ?? 'Network error');
  }

  @override
  Future<List<City>> cities() async =>
      asList((await _get('/v1/cities'))['cities'], City.fromJson);

  @override
  Future<City> city(String cityId) async => City.fromJson(await _get(_c(cityId)));

  @override
  Future<PlanResponse> plan(String cityId, PlanRequest request) async =>
      PlanResponse.fromJson(
          await _get('${_c(cityId)}/plan', query: request.toQuery()));

  @override
  Future<List<GeocodeResult>> geocode(String cityId, String query,
      {LatLng? near, int limit = 8}) async {
    final j = await _get('${_c(cityId)}/geocode', query: {
      'q': query,
      'lat': ?near?.lat,
      'lon': ?near?.lon,
      'limit': limit,
    });
    return asList(j['results'], GeocodeResult.fromJson);
  }

  @override
  Future<Place> reverse(String cityId, LatLng position) async {
    final j = await _get('${_c(cityId)}/reverse',
        query: {'lat': position.lat, 'lon': position.lon});
    return Place(
      name: j['name']?.toString() ?? position.toString(),
      position: LatLng(asDouble(j['lat']) ?? position.lat,
          asDouble(j['lon']) ?? position.lon),
    );
  }

  @override
  Future<List<Stop>> nearbyStops(String cityId, LatLng position,
      {int radiusMeters = 500, int limit = 30}) async {
    final j = await _get('${_c(cityId)}/stops/nearby', query: {
      'lat': position.lat,
      'lon': position.lon,
      'radius': radiusMeters,
      'limit': limit,
    });
    return asList(j['stops'], Stop.fromJson);
  }

  @override
  Future<StopDetail> stop(String cityId, String stopId) async =>
      StopDetail.fromJson(
          await _get('${_c(cityId)}/stops/${Uri.encodeComponent(stopId)}'));

  @override
  Future<DeparturesResponse> departures(String cityId, String stopId,
      {int limit = 20, int minutes = 60}) async =>
      DeparturesResponse.fromJson(await _get(
        '${_c(cityId)}/stops/${Uri.encodeComponent(stopId)}/departures',
        query: {'limit': limit, 'minutes': minutes},
      ));

  @override
  Future<List<RouteRef>> routes(String cityId,
      {Component? component, String? query}) async {
    final j = await _get('${_c(cityId)}/routes', query: {
      if (component != null) 'component': component.name,
      if (query != null && query.isNotEmpty) 'q': query,
    });
    return asList(j['routes'], RouteRef.fromJson);
  }

  @override
  Future<RouteDetail> route(String cityId, String routeId) async =>
      RouteDetail.fromJson(
          await _get('${_c(cityId)}/routes/${Uri.encodeComponent(routeId)}'));

  @override
  Future<List<NetworkShape>> network(String cityId) async =>
      asList((await _get('${_c(cityId)}/network'))['shapes'],
          NetworkShape.fromJson);

  @override
  Future<VehicleFrame> vehicles(String cityId,
      {String? routeId, List<double>? bbox}) async =>
      VehicleFrame.fromJson(await _get('${_c(cityId)}/vehicles', query: {
        'routeId': ?routeId,
        'bbox': ?bbox?.join(','),
      }));

  @override
  Stream<Map<String, dynamic>> vehicleEvents(String cityId) async* {
    final cancel = CancelToken();
    Response<ResponseBody> r;
    try {
      r = await _dio.get<ResponseBody>(
        '${_c(cityId)}/vehicles/stream',
        queryParameters: const {'deltas': 'true'},
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: Duration.zero,
          headers: const {'Accept': 'text/event-stream'},
        ),
      );
    } on DioException catch (e) {
      throw _toApiException(e);
    }
    final body = r.data;
    if (body == null) return;
    try {
      yield* parseSse(body.stream);
    } finally {
      cancel.cancel();
    }
  }

  @override
  Future<VehicleDetail> vehicle(String cityId, String vehicleId) async =>
      VehicleDetail.fromJson(await _get(
          '${_c(cityId)}/vehicles/${Uri.encodeComponent(vehicleId)}'));

  @override
  Future<List<TransitAlert>> alerts(String cityId,
      {String? routeId, String? stopId, bool active = true}) async {
    final j = await _get('${_c(cityId)}/alerts', query: {
      'routeId': ?routeId,
      'stopId': ?stopId,
      'active': active,
    });
    return asList(j['alerts'], TransitAlert.fromJson);
  }
}
