import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/watch/watch_sync.dart';

/// The watch bridge answers the same channel on both platforms, so these tests
/// pin the contract the Wear OS and watchOS sides both decode: which calls go
/// out, that identical snapshots are dropped, and that an unsupported platform
/// stays completely silent.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;
  late MethodChannel channel;

  setUp(() {
    calls = [];
    channel = const MethodChannel('opentransit/watch_test');
  });

  void handle({bool supported = true, bool syncOk = true}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'isSupported' => supported,
        'sync' => syncOk,
        _ => null,
      };
    });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<bool> syncOnce(WatchSync sync, {String stop = 'Portal Norte'}) => sync.sync(
        cityId: 'bogota',
        cityName: 'Bogotá',
        apiBaseUrl: 'https://api.example.org',
        favourites: [
          WatchFavourite(kind: 'stop', id: 'bogota:2000', label: stop),
        ],
      );

  test('an Android phone is a supported platform for the watch link', () async {
    handle();
    // The Wear OS bridge answers the same channel as WatchConnectivity, so the
    // guard must let Android through; before Wear OS existed it was iOS-only.
    final sync = WatchSync(channel: channel, platformSupported: true);
    expect(await syncOnce(sync), isTrue);
    expect(calls.map((c) => c.method), ['isSupported', 'sync']);
  });

  test('an unsupported platform never touches the channel', () async {
    handle();
    final sync = WatchSync(channel: channel, platformSupported: false);
    expect(await syncOnce(sync), isFalse);
    expect(calls, isEmpty);
  });

  test('identical snapshots are not resent', () async {
    handle();
    final sync = WatchSync(channel: channel, platformSupported: true);
    await syncOnce(sync);
    await syncOnce(sync);
    // A GO session syncs on every GPS fix; without this the watch radio would
    // wake for snapshots that render identically.
    expect(calls.where((c) => c.method == 'sync').length, 1);
  });

  test('a changed snapshot is resent', () async {
    handle();
    final sync = WatchSync(channel: channel, platformSupported: true);
    await syncOnce(sync);
    await syncOnce(sync, stop: 'Calle 100');
    expect(calls.where((c) => c.method == 'sync').length, 2);
  });

  test('a failed send is not remembered as delivered', () async {
    handle(syncOk: false);
    final sync = WatchSync(channel: channel, platformSupported: true);
    expect(await syncOnce(sync), isFalse);
    // The watch never got it, so the next attempt must go out again rather
    // than be deduped against a snapshot that was never delivered.
    expect(await syncOnce(sync), isFalse);
    expect(calls.where((c) => c.method == 'sync').length, 2);
  });

  test('the GO state travels with the field names the watch decodes', () async {
    handle();
    final sync = WatchSync(channel: channel, platformSupported: true);
    await sync.sync(
      cityId: 'bogota',
      cityName: 'Bogotá',
      apiBaseUrl: 'https://api.example.org',
      favourites: const [],
      go: WatchGoState(
        active: true,
        nextStopName: 'Portal Sur',
        minutesToNextStop: 4,
        routeShortName: 'G12',
        routeColor: '#B71C1C',
        etaAt: DateTime.fromMillisecondsSinceEpoch(1757200000000, isUtc: true),
        alight: true,
      ),
    );
    final go = (calls.last.arguments as Map)['go'] as Map;
    expect(go['active'], isTrue);
    expect(go['nextStopName'], 'Portal Sur');
    expect(go['minutesToNextStop'], 4);
    expect(go['routeShortName'], 'G12');
    expect(go['alight'], isTrue);
    // Seconds, not milliseconds: both watch apps build a Date from this.
    expect(go['etaEpochSeconds'], 1757200000.0);
  });
}
