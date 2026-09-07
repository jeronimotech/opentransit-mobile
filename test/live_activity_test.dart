import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/live_activity/live_activity.dart';
import 'package:opentransit_mobile/core/watch/watch_sync.dart';

/// Records what the platform side would have received.
class _FakeChannel {
  _FakeChannel(this.name, {this.supported = true});
  final String name;
  final bool supported;
  final calls = <(String, Map<Object?, Object?>?)>[];

  MethodChannel install() {
    final channel = MethodChannel(name);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add((call.method, call.arguments as Map<Object?, Object?>?));
      return switch (call.method) {
        'isSupported' => supported,
        'start' => true,
        _ => true,
      };
    });
    return channel;
  }
}

/// A channel with nothing on the other side, like Android or an old iOS.
MethodChannel _missingPlugin(String name) {
  final channel = MethodChannel(name);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (_) async => throw MissingPluginException());
  return channel;
}

LiveTripUpdate _update({int minutes = 5, String stop = 'Portal Sur', int leg = 0}) => LiveTripUpdate(
      etaAt: DateTime(2026, 9, 6, 18, 30),
      minutesToNextStop: minutes,
      nextStopName: stop,
      legIndex: leg,
      totalLegs: 4,
    );

const _trip = LiveTrip(
  cityId: 'bogota',
  tripLabel: 'Chicó → Portal Sur',
  destination: 'Portal Sur',
  routeShortName: 'G12',
  routeColor: '#B71C1C',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LiveActivity', () {
    test('start sends the trip and the first state together', () async {
      final fake = _FakeChannel('t.live1');
      final la = LiveActivity(channel: fake.install(), platformSupported: true);
      expect(await la.start(_trip, _update()), isTrue);
      expect(la.isRunning, isTrue);
      final (method, args) = fake.calls.last;
      expect(method, 'start');
      expect(args?['routeShortName'], 'G12');
      expect(args?['nextStopName'], 'Portal Sur');
      expect(args?['totalLegs'], 4);
    });

    test('a redundant update never reaches the platform', () async {
      final fake = _FakeChannel('t.live2');
      final la = LiveActivity(channel: fake.install(), platformSupported: true);
      await la.start(_trip, _update());
      final before = fake.calls.length;
      expect(await la.update(_update()), isTrue, reason: 'same state still succeeds');
      expect(fake.calls.length, before, reason: 'but no platform hop');
      await la.update(_update(minutes: 3));
      expect(fake.calls.last.$1, 'update');
    });

    test('update and end are no-ops before start', () async {
      final fake = _FakeChannel('t.live3');
      final la = LiveActivity(channel: fake.install(), platformSupported: true);
      expect(await la.update(_update()), isFalse);
      expect(await la.end(), isFalse);
      expect(fake.calls, isEmpty);
    });

    test('an unsupported platform reports false instead of throwing', () async {
      final la = LiveActivity(channel: _FakeChannel('t.live4', supported: false).install(), platformSupported: true);
      expect(await la.isSupported(), isFalse);
      expect(await la.start(_trip, _update()), isFalse);
      expect(la.isRunning, isFalse);
    });

    test('a missing plugin is swallowed', () async {
      final la = LiveActivity(channel: _missingPlugin('t.live5'), platformSupported: true);
      expect(await la.isSupported(), isFalse);
      expect(await la.start(_trip, _update()), isFalse);
    });

    test('rendersSameAs tolerates sub-minute ETA drift only', () {
      final base = _update();
      expect(base.rendersSameAs(_update()), isTrue);
      expect(
        LiveTripUpdate(
          etaAt: base.etaAt.add(const Duration(seconds: 30)),
          minutesToNextStop: 5,
          nextStopName: 'Portal Sur',
          legIndex: 0,
          totalLegs: 4,
        ).rendersSameAs(base),
        isTrue,
      );
      expect(
        LiveTripUpdate(
          etaAt: base.etaAt.add(const Duration(minutes: 4)),
          minutesToNextStop: 5,
          nextStopName: 'Portal Sur',
          legIndex: 0,
          totalLegs: 4,
        ).rendersSameAs(base),
        isFalse,
      );
      expect(_update(leg: 1).rendersSameAs(base), isFalse);
      expect(base.rendersSameAs(null), isFalse);
    });
  });

  group('WatchSync', () {
    test('identical snapshots are sent once', () async {
      final fake = _FakeChannel('t.watch1');
      final w = WatchSync(channel: fake.install(), platformSupported: true);
      const fav = WatchFavourite(kind: 'stop', id: 'bogota:2000', label: 'Portal Norte');
      Future<bool> send() => w.sync(
            cityId: 'bogota',
            cityName: 'Bogotá',
            apiBaseUrl: 'https://api.example',
            favourites: const [fav],
          );
      expect(await send(), isTrue);
      final after = fake.calls.where((c) => c.$1 == 'sync').length;
      expect(await send(), isTrue);
      expect(fake.calls.where((c) => c.$1 == 'sync').length, after,
          reason: 'the watch radio is not woken for an unchanged board');
    });

    test('a changed GO state does get through', () async {
      final fake = _FakeChannel('t.watch2');
      final w = WatchSync(channel: fake.install(), platformSupported: true);
      await w.sync(cityId: 'bogota', cityName: 'Bogotá', apiBaseUrl: 'x', favourites: const []);
      await w.sync(
        cityId: 'bogota',
        cityName: 'Bogotá',
        apiBaseUrl: 'x',
        favourites: const [],
        go: const WatchGoState(active: true, nextStopName: 'Calle 100', minutesToNextStop: 2, alight: true),
      );
      final last = fake.calls.last.$2!['go']! as Map<Object?, Object?>;
      expect(last['active'], isTrue);
      expect(last['alight'], isTrue);
      expect(last['nextStopName'], 'Calle 100');
    });

    test('off iOS the bridge never even opens the channel', () async {
      final fake = _FakeChannel('t.watch4');
      final w = WatchSync(channel: fake.install(), platformSupported: false);
      expect(await w.isSupported(), isFalse);
      expect(
        await w.sync(cityId: 'bogota', cityName: 'B', apiBaseUrl: 'x', favourites: const []),
        isFalse,
      );
      expect(fake.calls, isEmpty);
    });

    test('no watch means false, not an exception', () async {
      final w = WatchSync(channel: _FakeChannel('t.watch3', supported: false).install(), platformSupported: true);
      expect(await w.isSupported(), isFalse);
      expect(
        await w.sync(cityId: 'bogota', cityName: 'B', apiBaseUrl: 'x', favourites: const []),
        isFalse,
      );
    });
  });
}
