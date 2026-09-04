import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../models/models.dart';
import '../utils/geo.dart';
import '../utils/polyline.dart';
import 'api_client.dart';

/// Fixture-backed client used for demos, tests and offline development.
///
/// Fixtures were generated with times around `2026-09-04T08:00-05:00`; every
/// ISO timestamp is shifted so that base instant maps to "now" when loaded.
class MockApiClient implements ApiClient {
  MockApiClient({AssetBundle? bundle, DateTime? now, this.latency = const Duration(milliseconds: 250)})
      : _bundle = bundle ?? rootBundle,
        _now = now;

  static final DateTime fixtureBase = DateTime.parse('2026-09-04T08:00:00-05:00');
  static const _isoPattern = r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}';

  final AssetBundle _bundle;
  final DateTime? _now;
  final Duration latency;
  final Map<String, dynamic> _cache = {};

  DateTime get now => _now ?? DateTime.now();

  Future<dynamic> _load(String name) async {
    if (_cache.containsKey(name)) return _cache[name];
    final text = await _bundle.loadString('assets/fixtures/$name.json');
    final shifted = rebaseTimes(jsonDecode(text), now.difference(fixtureBase));
    _cache[name] = shifted;
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return shifted;
  }

  Future<Map<String, dynamic>> _map(String name) async =>
      Map<String, dynamic>.from(await _load(name) as Map);

  /// Recursively shifts every ISO-8601 timestamp string by [shift].
  static dynamic rebaseTimes(dynamic node, Duration shift) {
    if (node is Map) {
      return {for (final e in node.entries) e.key: rebaseTimes(e.value, shift)};
    }
    if (node is List) return node.map((e) => rebaseTimes(e, shift)).toList();
    if (node is String && RegExp(_isoPattern).hasMatch(node)) {
      final t = DateTime.tryParse(node);
      if (t != null) return t.add(shift).toIso8601String();
    }
    return node;
  }

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[áàä]'), 'a')
      .replaceAll(RegExp('[éèë]'), 'e')
      .replaceAll(RegExp('[íìï]'), 'i')
      .replaceAll(RegExp('[óòö]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u')
      .replaceAll('ñ', 'n');

  @override
  Future<List<City>> cities() async =>
      asList((await _map('cities'))['cities'], City.fromJson);

  @override
  Future<City> city(String cityId) async {
    final all = await cities();
    return all.firstWhere((c) => c.id == cityId,
        orElse: () => throw ApiException('CITY_NOT_FOUND', 'No city $cityId', status: 404));
  }

  @override
  Future<PlanResponse> plan(String cityId, PlanRequest request) async {
    final j = await _map('plan');
    final base = PlanResponse.fromJson(j);
    // Shift the fixture so the first itinerary departs at the requested time.
    final anchor = request.time ?? now;
    final shift = anchor.difference(base.itineraries.first.startTime);
    final shifted = PlanResponse.fromJson(
        Map<String, dynamic>.from(rebaseTimes(j, shift) as Map));
    var its = shifted.itineraries;
    if (request.wheelchair) its = its.where((i) => i.accessible == true).toList();
    if (!request.modes.any((m) => m.isTransit)) its = const [];
    return PlanResponse(
      from: request.from,
      to: request.to,
      itineraries: its.take(request.numItineraries).toList(),
      routerEngine: 'mock',
      routerVersion: '0',
      warnings: its.isEmpty ? const ['NO_ITINERARIES'] : const [],
    );
  }

  @override
  Future<List<GeocodeResult>> geocode(String cityId, String query,
      {LatLng? near, int limit = 8}) async {
    final all = asList((await _map('geocode'))['results'], GeocodeResult.fromJson);
    final q = _norm(query.trim());
    if (q.isEmpty) return all.take(limit).toList();
    final hits = all.where((r) => _norm(r.name).contains(q) || _norm(r.label ?? '').contains(q)).toList();
    hits.sort((a, b) {
      final pa = _norm(a.name).startsWith(q) ? 0 : 1;
      final pb = _norm(b.name).startsWith(q) ? 0 : 1;
      if (pa != pb) return pa - pb;
      if (near != null) {
        return haversineMeters(near, a.position).compareTo(haversineMeters(near, b.position));
      }
      return 0;
    });
    return hits.take(limit).toList();
  }

  @override
  Future<Place> reverse(String cityId, LatLng position) async {
    final stops = await nearbyStops(cityId, position, radiusMeters: 100000, limit: 1);
    final name = stops.isEmpty
        ? position.toString()
        : '${stops.first.name} (${formatDistance(stops.first.distanceMeters ?? 0)})';
    return Place(name: name, position: position);
  }

  @override
  Future<List<Stop>> nearbyStops(String cityId, LatLng position,
      {int radiusMeters = 500, int limit = 30}) async {
    final raw = (await _map('stops_nearby'))['stops'] as List;
    final stops = raw.whereType<Map>().map((m) {
      final j = Map<String, dynamic>.from(m);
      final s = Stop.fromJson(j);
      return Stop(
        id: s.id, code: s.code, name: s.name, position: s.position,
        locationType: s.locationType, component: s.component,
        wheelchair: s.wheelchair, parentStationId: s.parentStationId,
        distanceMeters: haversineMeters(position, s.position).round(),
      );
    }).toList()
      ..sort((a, b) => a.distanceMeters!.compareTo(b.distanceMeters!));
    final within = stops.where((s) => s.distanceMeters! <= radiusMeters).toList();
    return (within.isEmpty ? stops.take(math.min(5, limit)) : within.take(limit)).toList();
  }

  @override
  Future<StopDetail> stop(String cityId, String stopId) async {
    final all = await _map('stops');
    final j = all[stopId];
    if (j is! Map) throw ApiException('STOP_NOT_FOUND', 'No stop $stopId', status: 404);
    return StopDetail.fromJson(Map<String, dynamic>.from(j));
  }

  @override
  Future<DeparturesResponse> departures(String cityId, String stopId,
      {int limit = 20, int minutes = 60}) async {
    final j = await _map('departures');
    final base = DeparturesResponse.fromJson(j);
    final detail = await stop(cityId, stopId);
    // Re-anchor so the first departure is a few minutes from now on every call.
    final shift = now.add(const Duration(minutes: 2)).difference(base.departures.first.scheduledTime);
    final shifted = DeparturesResponse.fromJson(
        Map<String, dynamic>.from(rebaseTimes(j, shift) as Map));
    final horizon = now.add(Duration(minutes: minutes));
    return DeparturesResponse(
      stop: detail.stop,
      generatedAt: now,
      departures: shifted.departures
          .where((d) => d.effectiveTime.isBefore(horizon))
          .take(limit)
          .toList(),
    );
  }

  @override
  Future<List<RouteRef>> routes(String cityId, {Component? component, String? query}) async {
    var all = asList((await _map('routes'))['routes'], RouteRef.fromJson);
    if (component != null) all = all.where((r) => r.component == component).toList();
    if (query != null && query.isNotEmpty) {
      final q = _norm(query);
      all = all.where((r) => _norm(r.shortName).contains(q) || _norm(r.longName).contains(q)).toList();
    }
    return all;
  }

  @override
  Future<RouteDetail> route(String cityId, String routeId) async {
    final j = (await _map('route_detail'))[routeId];
    if (j is! Map) throw ApiException('ROUTE_NOT_FOUND', 'No route $routeId', status: 404);
    return RouteDetail.fromJson(Map<String, dynamic>.from(j));
  }

  @override
  Future<List<NetworkShape>> network(String cityId) async =>
      asList((await _map('network'))['shapes'], NetworkShape.fromJson);

  @override
  Future<VehicleFrame> vehicles(String cityId, {String? routeId, List<double>? bbox}) async {
    final frame = VehicleFrame.fromJson(await _map('vehicles'));
    if (routeId == null) return frame;
    return VehicleFrame(
      seq: frame.seq, generatedAt: frame.generatedAt, feedTimestamp: frame.feedTimestamp,
      health: frame.health,
      vehicles: {for (final v in frame.vehicles.values) if (v.routeId == routeId) v.id: v},
    );
  }

  /// Emits the full frame, then a delta every 4 s nudging vehicles along the
  /// route they are on (using the network shapes) so the map visibly moves.
  @override
  Stream<Map<String, dynamic>> vehicleEvents(String cityId) async* {
    final full = await _map('vehicles');
    yield full;
    final shapes = {for (final s in await network(cityId)) s.routeId: decodeGeometry(s.geometry)};
    var frame = VehicleFrame.fromJson(full);
    final rnd = math.Random(42);
    var seq = frame.seq;
    while (true) {
      await Future<void>.delayed(const Duration(seconds: 4));
      final updated = <Map<String, dynamic>>[];
      for (final v in frame.vehicles.values) {
        final line = shapes[v.routeId];
        if (line == null || line.length < 2 || rnd.nextDouble() < 0.3) continue;
        // Jump to the next vertex after the closest one.
        var best = 0;
        var bestD = double.infinity;
        for (var i = 0; i < line.length; i++) {
          final d = haversineMeters(v.position, line[i]);
          if (d < bestD) { bestD = d; best = i; }
        }
        final next = line[(best + 1) % line.length];
        updated.add({'id': v.id, 'lat': next.lat, 'lon': next.lon, 'timestamp': now.toIso8601String()});
      }
      seq += 1;
      final event = {
        'type': 'delta', 'seq': seq, 'generatedAt': now.toIso8601String(),
        'updated': updated, 'removed': const <String>[],
      };
      frame = frame.apply(event);
      yield event;
    }
  }

  @override
  Future<VehicleDetail> vehicle(String cityId, String vehicleId) async {
    final j = await _map('vehicle_detail');
    final frame = VehicleFrame.fromJson(await _map('vehicles'));
    final v = frame.vehicles[vehicleId];
    if (v == null) throw ApiException('VEHICLE_NOT_FOUND', 'No vehicle $vehicleId', status: 404);
    final detail = VehicleDetail.fromJson(j);
    return VehicleDetail(
      vehicle: v, route: detail.route, tripHeadsign: detail.tripHeadsign, shape: detail.shape,
      currentStop: detail.currentStop, nextStop: detail.nextStop, etaSeconds: detail.etaSeconds,
      delaySeconds: detail.delaySeconds, historyPoints: detail.historyPoints,
      avgKmh: detail.avgKmh, alerts: detail.alerts,
    );
  }

  @override
  Future<List<TransitAlert>> alerts(String cityId,
      {String? routeId, String? stopId, bool active = true}) async {
    var all = asList((await _map('alerts'))['alerts'], TransitAlert.fromJson);
    if (routeId != null) all = all.where((a) => a.routeIds.contains(routeId)).toList();
    if (stopId != null) all = all.where((a) => a.stopIds.contains(stopId)).toList();
    if (active) all = all.where((a) => a.isActiveAt(now)).toList();
    return all;
  }
}
