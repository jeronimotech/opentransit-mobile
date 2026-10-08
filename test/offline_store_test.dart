library;

/// Installing and reading a bundle. The HTTP request is dio's problem; everything after it — the
/// decompress, the offset index, the validation, the per-stop read — is this file's.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/offline/offline_store.dart';

Map<String, dynamic> _header({String city = 'testville', int v = 1}) => {
      'v': v,
      'city': city,
      'feedVersion': '65',
      'builtAt': '2026-10-07T02:00:00Z',
      'routes': [
        {'id': 'R1', 'short': 'G12', 'long': 'Norte', 'type': 3},
        {'id': 'R2', 'short': 'N7', 'long': 'Nocturno', 'type': 3},
      ],
      'headsigns': ['Norte', 'Centro'],
      'services': [
        {'idx': 0, 'id': 'WK', 'days': [1, 1, 1, 1, 1, 0, 0], 'from': '20260101', 'to': '20261231'},
      ],
      'serviceExceptions': [],
      'stops': [
        {'id': 'S1', 'name': 'Portal Sur', 'lat': 4.59556, 'lon': -74.17111, 'type': 0},
        {'id': 'S2', 'name': 'Centro', 'lat': 4.6012, 'lon': -74.0718, 'type': 0},
        {'id': 'S3', 'name': 'Nunca', 'lat': 4.7, 'lon': -74.2, 'type': 0},
      ],
      'stats': {'departures': 6},
    };

/// A gzipped NDJSON bundle on disk, the shape build_offline_bundle.py publishes.
Future<File> _bundle(Directory dir, {
  Map<String, dynamic>? header,
  List<String>? stopLines,
  String name = 'b.ndjson.gz',
}) async {
  final lines = [
    jsonEncode(header ?? _header()),
    ...(stopLines ??
        [
          // S1: G12 "Norte" on the weekday service at 06:00, 06:10, 06:20, plus a 25:10 night bus.
          '{"s":0,"g":[[0,0,0,[360,10,10]],[1,1,0,[1510]]]}',
          '{"s":1,"g":[[0,1,0,[480,60]]]}',
        ]),
  ];
  final raw = utf8.encode('${lines.join('\n')}\n');
  final f = File('${dir.path}/$name');
  await f.writeAsBytes(gzip.encode(raw));
  return f;
}

void main() {
  late Directory tmp;
  late OfflineStore store;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('offline_test');
    store = OfflineStore(directory: tmp);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('nothing is installed until it is', () async {
    expect(await store.meta('testville'), isNull);
    expect(await store.open('testville'), isNull);
    expect(await store.bytesOnDisk('testville'), 0);
  });

  test('installing records what a rider actually gave up disk for', () async {
    final gz = await _bundle(tmp);
    final m = await store.installFromFile('testville', gz);
    expect(m.city, 'testville');
    expect(m.formatVersion, 1);
    expect(m.feedVersion, '65');
    expect(m.departures, 6);
    // Only the two stops with departures get a line; S3 is in the header but has no board.
    expect(m.stops, 2);
    expect(m.bytes, greaterThan(0));
    expect(await store.bytesOnDisk('testville'), greaterThan(m.bytes));
    expect(await store.meta('testville'), isNotNull);
  });

  test('a stop is read by offset, and both service days are considered', () async {
    await store.installFromFile('testville', await _bundle(tmp));
    final b = (await store.open('testville'))!;
    expect(b.header.stops.length, 3);

    // 06:05 Wednesday: 06:00 has gone, 06:10 and 06:20 remain.
    final at = DateTime(2026, 10, 7, 6, 5);
    final deps = await b.departures('S1', at: at);
    expect(deps.map((d) => '${d.time.hour}:${d.time.minute}'), ['6:10', '6:20']);
    expect(deps.first.route.short, 'G12');
    expect(deps.first.headsign, 'Norte');

    // Wednesday's own 25:10 night bus is a real later departure — 01:10 on Thursday — and it is
    // outside the three-hour window on purpose. True and useless is not what a board is for.
    final wide = await b.departures('S1', at: at, within: const Duration(hours: 24));
    expect(wide.map((d) => '${d.time.day} ${d.time.hour}:${d.time.minute}'),
        ['7 6:10', '7 6:20', '8 1:10']);
  });

  test('just after midnight the night bus is yesterday\'s service, and still shows', () async {
    // The 25:10 departure belongs to Tuesday's service day. A board that only asked for Wednesday
    // would be empty at exactly the hour someone is waiting in the dark.
    await store.installFromFile('testville', await _bundle(tmp));
    final b = (await store.open('testville'))!;
    final deps = await b.departures('S1', at: DateTime(2026, 10, 8, 0, 30));
    expect(deps, isNotEmpty);
    expect(deps.first.time, DateTime(2026, 10, 8, 1, 10));
    expect(deps.first.route.short, 'N7');
  });

  test('a stop with no board, and an unknown stop, both answer nothing', () async {
    await store.installFromFile('testville', await _bundle(tmp));
    final b = (await store.open('testville'))!;
    expect(await b.departures('S3', at: DateTime(2026, 10, 7, 6, 0)), isEmpty);
    expect(await b.departures('NOPE', at: DateTime(2026, 10, 7, 6, 0)), isEmpty);
  });

  test('a bundle for another city is refused', () async {
    // Installing Toronto's timetable as Bogotá's would show plausible times for stops that do not
    // exist here, which is worse than no board at all.
    final gz = await _bundle(tmp, header: _header(city: 'toronto'));
    await expectLater(
        store.installFromFile('testville', gz), throwsA(isA<OfflineInstallException>()));
    expect(await store.meta('testville'), isNull);
  });

  test('a format from the future is refused rather than half-read', () async {
    final gz = await _bundle(tmp, header: _header(v: 2));
    await expectLater(
        store.installFromFile('testville', gz), throwsA(isA<OfflineInstallException>()));
  });

  test('a bundle with no departures is refused', () async {
    final gz = await _bundle(tmp, stopLines: const []);
    await expectLater(
        store.installFromFile('testville', gz), throwsA(isA<OfflineInstallException>()));
  });

  test('a failed install leaves the previous timetable working', () async {
    await store.installFromFile('testville', await _bundle(tmp));
    final before = await store.meta('testville');

    final bad = await _bundle(tmp, header: _header(v: 99), name: 'bad.ndjson.gz');
    await expectLater(
        store.installFromFile('testville', bad), throwsA(isA<OfflineInstallException>()));

    final after = await store.meta('testville');
    expect(after!.installedAt, before!.installedAt);
    final b = (await store.open('testville'))!;
    expect(await b.departures('S1', at: DateTime(2026, 10, 7, 6, 5)), isNotEmpty);
  });

  test('reinstalling replaces, and removing leaves nothing behind', () async {
    await store.installFromFile('testville', await _bundle(tmp));
    await store.installFromFile('testville', await _bundle(tmp));
    expect(await store.open('testville'), isNotNull);

    await store.remove('testville');
    expect(await store.meta('testville'), isNull);
    expect(await store.open('testville'), isNull);
    expect(await store.bytesOnDisk('testville'), 0);
  });

  test('an unreadable meta file reads as nothing installed', () async {
    await store.installFromFile('testville', await _bundle(tmp));
    await File('${tmp.path}/offline/testville.meta').writeAsString('not json at all');
    // Better to offer a download than to show a timetable we cannot vouch for.
    expect(await store.meta('testville'), isNull);
    expect(await store.open('testville'), isNull);
  });

  test('progress reaches 1 when the install is done', () async {
    final seen = <double>[];
    await store.installFromFile('testville', await _bundle(tmp), onProgress: seen.add);
    expect(seen.last, 1.0);
  });

  test('the stop page works offline, routes and all', () async {
    await store.installFromFile('testville', await _bundle(tmp));
    final b = (await store.open('testville'))!;
    final d = (await b.stopDetail('S1', 'testville'))!;

    expect(d.stop.name, 'Portal Sur');
    // Both routes that call at S1, from its own board — whatever appears there is what serves it.
    expect(d.routes.map((r) => r.shortName).toSet(), {'G12', 'N7'});
    expect(d.routes.first.id, startsWith('testville:'));
  });

  test('a stop the bundle never heard of is null, not an empty page', () async {
    // Null lets the caller rethrow the original network error, which the rider can retry. An empty
    // StopDetail would claim this stop exists and nothing stops there.
    await store.installFromFile('testville', await _bundle(tmp));
    final b = (await store.open('testville'))!;
    expect(await b.stopDetail('NOPE', 'testville'), isNull);
  });

  test('a stop with no board still has a page', () async {
    // S3 is in the header and has no departures. The page should open and simply list no routes.
    await store.installFromFile('testville', await _bundle(tmp));
    final b = (await store.open('testville'))!;
    final d = (await b.stopDetail('S3', 'testville'))!;
    expect(d.stop.name, 'Nunca');
    expect(d.routes, isEmpty);
  });
}