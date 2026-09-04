import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/api/sse.dart';
import 'package:opentransit_mobile/core/models/models.dart';

void main() {
  final full = {
    'type': 'full',
    'seq': 1,
    'generatedAt': '2026-09-04T08:00:00-05:00',
    'count': 2,
    'health': {'entityAgeP50Seconds': 20, 'pctTripResolved': 90.0, 'httpStatus': 200},
    'vehicles': [
      {'id': 'A', 'routeId': 'bogota:B10', 'routeShortName': 'B10', 'component': 'trunk', 'lat': 4.7, 'lon': -74.0, 'tripResolved': true, 'timestamp': '2026-09-04T07:59:50-05:00'},
      {'id': 'B', 'routeId': 'bogota:K43', 'routeShortName': 'K43', 'component': 'trunk', 'lat': 4.6, 'lon': -74.1, 'tripResolved': false},
    ],
  };

  test('full frame indexes vehicles by id', () {
    final f = VehicleFrame.fromJson(full);
    expect(f.count, 2);
    expect(f.vehicles['A']!.routeShortName, 'B10');
    expect(f.health.httpStatus, 200);
  });

  test('delta updates positions, adds and removes', () {
    final f = VehicleFrame.fromJson(full);
    final next = f.apply({
      'type': 'delta',
      'seq': 2,
      'generatedAt': '2026-09-04T08:00:15-05:00',
      'updated': [
        {'id': 'A', 'lat': 4.71, 'lon': -74.01, 'timestamp': '2026-09-04T08:00:10-05:00'},
        {'id': 'C', 'routeId': 'bogota:G12', 'routeShortName': 'G12', 'component': 'zonal', 'lat': 4.5, 'lon': -74.2},
      ],
      'removed': ['B'],
    });
    expect(next.seq, 2);
    expect(next.count, 2);
    final a = next.vehicles['A']!;
    expect(a.position.lat, 4.71);
    expect(a.routeShortName, 'B10'); // untouched fields survive
    expect(a.tripResolved, isTrue);
    expect(a.timestamp!.isAfter(f.vehicles['A']!.timestamp!), isTrue);
    expect(next.vehicles.containsKey('B'), isFalse);
    expect(next.vehicles['C']!.component, Component.zonal);
    // Original frame is not mutated.
    expect(f.count, 2);
    expect(f.vehicles['A']!.position.lat, 4.7);
  });

  test('a later full frame replaces everything', () {
    final f = VehicleFrame.fromJson(full);
    final next = f.apply({...full, 'seq': 9, 'vehicles': [(full['vehicles']! as List)[0]]});
    expect(next.seq, 9);
    expect(next.count, 1);
  });

  test('delta with a trip change clears stale fields explicitly', () {
    final f = VehicleFrame.fromJson(full);
    final next = f.apply({
      'type': 'delta',
      'updated': [
        {'id': 'A', 'tripId': null, 'routeId': null, 'routeShortName': null, 'lat': 4.7, 'lon': -74.0},
      ],
    });
    expect(next.vehicles['A']!.routeId, isNull);
    expect(next.vehicles['A']!.routeShortName, isNull);
  });

  test('SSE parser handles comments, multi-line data and blank lines', () async {
    final raw = [
      ': keep-alive\n\n',
      'data: ${jsonEncode(full)}\n\n',
      'event: delta\ndata: {"type":"delta",\ndata: "seq":2,"updated":[],"removed":["B"]}\n\n',
      'data: not json\n\n',
      ': keep-alive\n\n',
    ].map(utf8.encode);
    final events = await parseSse(Stream.fromIterable(raw)).toList();
    expect(events, hasLength(2));
    expect(events[0]['type'], 'full');
    expect(events[1]['type'], 'delta');
    expect(events[1]['removed'], ['B']);
  });

  test('SSE parser decodes large frames off-thread, in order', () async {
    final big = {
      'type': 'full', 'seq': 1,
      'vehicles': [for (var i = 0; i < 6000; i++) {'id': 'V$i', 'lat': 4.6 + i * 1e-5, 'lon': -74.1, 'component': 'zonal'}],
    };
    final raw = ['data: ${jsonEncode(big)}\n\n', 'data: {"type":"delta","seq":2,"updated":[],"removed":[]}\n\n'].map(utf8.encode);
    final events = await parseSse(Stream.fromIterable(raw)).toList();
    expect(events.map((e) => e['seq']), [1, 2]);
    expect(VehicleFrame.fromJson(events.first).count, 6000);
  });

  test('SSE parser accepts Uint8List chunks (what dio emits)', () async {
    final chunk = Uint8List.fromList(utf8.encode('data: {"type":"full","seq":7,"vehicles":[]}\n\n'));
    final events = await parseSse(Stream<Uint8List>.fromIterable([chunk])).toList();
    expect(events.single['seq'], 7);
  });

  test('SSE parser copes with chunk boundaries mid-line', () async {
    final text = 'data: {"type":"full","seq":1,"vehicles":[]}\n\ndata: {"type":"delta","seq":2}\n\n';
    final bytes = utf8.encode(text);
    final chunks = <List<int>>[];
    for (var i = 0; i < bytes.length; i += 7) {
      chunks.add(bytes.sublist(i, (i + 7).clamp(0, bytes.length)));
    }
    final events = await parseSse(Stream.fromIterable(chunks)).toList();
    expect(events.map((e) => e['seq']), [1, 2]);
  });
}
