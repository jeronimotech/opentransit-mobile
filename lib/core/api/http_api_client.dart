import 'dart:async';

import 'package:dio/dio.dart';

import '../models/models.dart';
import '../utils/geo.dart';
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
  Future<CityHealth> health(String cityId) async =>
      CityHealth.fromJson(await _get('${_c(cityId)}/health'));

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
  Future<BoardResponse> board(String cityId, String stopId,
      {int minutes = 60, int perRoute = 3}) async {
    try {
      return BoardResponse.fromJson(await _get(
        '${_c(cityId)}/stops/${Uri.encodeComponent(stopId)}/board',
        query: {'minutes': minutes, 'perRoute': perRoute},
      ));
    } on ApiException catch (e) {
      // Older API without /board: group the flat departures list ourselves.
      if (!e.isNotFound || e.code == 'STOP_NOT_FOUND') rethrow;
      final d = await departures(cityId, stopId, limit: 60, minutes: minutes);
      return BoardResponse.fromDepartures(d, perRoute: perRoute);
    }
  }

  @override
  Future<NextBusesResponse> nextBuses(String cityId, String stopId, String routeId,
      {int limit = 3}) async {
    try {
      return NextBusesResponse.fromJson(await _get(
        '${_c(cityId)}/stops/${Uri.encodeComponent(stopId)}/routes/${Uri.encodeComponent(routeId)}/next',
        query: {'limit': limit},
      ));
    } on ApiException catch (e) {
      // Older API without /next: derive scheduled rows from the board and
      // attach live buses of that route from the vehicles snapshot.
      if (!e.isNotFound || e.code == 'STOP_NOT_FOUND' || e.code == 'ROUTE_NOT_FOUND') rethrow;
      final b = await board(cityId, stopId, perRoute: limit);
      final rows = b.rows.where((r) => r.route.id == routeId).toList();
      final route = rows.isNotEmpty
          ? rows.first.route
          : (await stop(cityId, stopId)).routes.firstWhere((r) => r.id == routeId,
              orElse: () => throw ApiException('ROUTE_NOT_FOUND', 'route $routeId not at $stopId', status: 404));
      final times = [for (final r in rows) ...r.next]..sort((a, b) => a.time.compareTo(b.time));
      VehicleFrame? frame;
      try {
        frame = await vehicles(cityId, routeId: routeId);
      } catch (_) {}
      return NextBusesResponse(
        stop: b.stop,
        route: route,
        freshness: b.freshness,
        next: [
          for (final t in times.take(limit))
            NextBus(
              minutes: t.minutes, time: t.time,
              source: t.realtime ? 'live' : 'scheduled',
              vehicle: t.vehicleId == null ? null : frame?.vehicles[t.vehicleId!],
              tripId: t.tripId,
            ),
        ],
      );
    }
  }

  @override
  Future<List<Poi>> pois(String cityId, List<double> bbox, {List<String>? types}) async =>
      Poi.fromCollection(await _get('${_c(cityId)}/pois', query: {
        'bbox': bbox.join(','),
        if (types != null && types.isNotEmpty) 'type': types.join(','),
      }));

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
  Stream<Map<String, dynamic>> vehicleEvents(String cityId,
      {List<double>? bbox, List<String>? routeIds}) async* {
    final cancel = CancelToken();
    Response<ResponseBody> r;
    try {
      r = await _dio.get<ResponseBody>(
        '${_c(cityId)}/vehicles/stream',
        queryParameters: {
          'deltas': 'true',
          if (bbox != null) 'bbox': bbox.join(','),
          if (routeIds != null && routeIds.isNotEmpty) 'routeIds': routeIds.join(','),
        },
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

  // ── v1.2 shared bikes ──

  @override
  Future<List<BikeShareNetwork>> rentalNetworks(String cityId) async {
    try {
      return asList((await _get('${_c(cityId)}/rental/networks'))['networks'], BikeShareNetwork.fromJson);
    } on ApiException catch (e) {
      if (e.isNotFound) return const []; // API predates v1.2
      rethrow;
    }
  }

  @override
  Future<RentalStationsResponse> rentalStations(String cityId,
      {List<double>? bbox, String? networkId, int limit = 500}) async {
    try {
      return RentalStationsResponse.fromJson(await _get('${_c(cityId)}/rental/stations', query: {
        'bbox': ?bbox?.join(','),
        'networkId': ?networkId,
        'limit': limit,
      }));
    } on ApiException catch (e) {
      if (e.isNotFound) return RentalStationsResponse(generatedAt: DateTime.now(), stations: const []);
      rethrow;
    }
  }

  @override
  Future<RentalStation> rentalStation(String cityId, String stationId) async =>
      RentalStation.fromJson(await _get('${_c(cityId)}/rental/stations/${Uri.encodeComponent(stationId)}'));

  @override
  Future<List<RentalStation>> nearbyRentalStations(String cityId, LatLng position,
      {int radiusMeters = 800, int limit = 5}) async {
    // Preferred: the nearby endpoint with `include=rental` (distance from PostGIS).
    try {
      final j = await _get('${_c(cityId)}/stops/nearby', query: {
        'lat': position.lat, 'lon': position.lon, 'radius': radiusMeters, 'limit': 50, 'include': 'rental',
      });
      // The API answers rental stations under `rentalStations`; older builds
      // mixed them into `stops` with `kind: rental_station`. Accept both.
      final items = [
        ...(j['rentalStations'] as List? ?? const []),
        ...(j['stops'] as List? ?? const []).whereType<Map>().where((e) => e['kind'] == 'rental_station'),
      ]
          .whereType<Map>()
          .map((e) => RentalStation.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => (a.distanceMeters ?? 1 << 30).compareTo(b.distanceMeters ?? 1 << 30));
      if (items.isNotEmpty) return items.take(limit).toList();
    } on ApiException catch (e) {
      if (!e.isNotFound) rethrow;
    }
    // Fallback (older API without `include`): a bbox query around the point.
    final d = radiusMeters / 111000;
    final r = await rentalStations(cityId, bbox: [
      position.lon - d, position.lat - d, position.lon + d, position.lat + d,
    ]);
    final near = [
      for (final s in r.stations) s.copyWith(distanceMeters: haversineMeters(position, s.position).round()),
    ]..sort((a, b) => a.distanceMeters!.compareTo(b.distanceMeters!));
    return near.where((s) => s.distanceMeters! <= radiusMeters).take(limit).toList();
  }

  // ── v1.4 on-demand mobility ──

  @override
  Future<List<OnDemandProvider>> onDemandProviders(String cityId) async {
    try {
      return asList((await _get('${_c(cityId)}/ondemand/providers'))['providers'], OnDemandProvider.fromJson);
    } on ApiException catch (e) {
      if (e.isNotFound) return const []; // API predates v1.4
      rethrow;
    }
  }

  @override
  Future<OnDemandEstimate> onDemandEstimate(String cityId, LatLng from, LatLng to,
      {DateTime? time, String? providerId}) async =>
      OnDemandEstimate.fromJson(await _get('${_c(cityId)}/ondemand/estimate', query: {
        'fromLat': from.lat, 'fromLon': from.lon, 'toLat': to.lat, 'toLon': to.lon,
        'time': ?time?.toIso8601String(),
        'providerId': ?providerId,
      }));

  @override
  Future<OnDemandHandoff> onDemandHandoff(String cityId, String providerId, LatLng from, LatLng to,
      {String? fromName, String? toName, String platform = 'web'}) async =>
      OnDemandHandoff.fromJson(await _get('${_c(cityId)}/ondemand/handoff', query: {
        'providerId': providerId,
        'fromLat': from.lat, 'fromLon': from.lon, 'toLat': to.lat, 'toLon': to.lon,
        'fromName': ?fromName, 'toName': ?toName, 'platform': platform,
      }));
}
