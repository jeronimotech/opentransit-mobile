library;

/// Choosing the home-screen icon. The platform work is verified in the built artefacts — the APK's
/// manifest for Android, the asset catalog and xcconfig for iOS — so what is testable here is the
/// Dart side's refusal to pretend.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/city_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The host is macOS; the feature only exists on a phone. `defaultTargetPlatform` is what makes
  // that overridable, which is half the reason the production code reads it instead of dart:io.
  setUpAll(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDownAll(() => debugDefaultTargetPlatformOverride = null);

  const channel = MethodChannel('org.opentransit/city_icon');
  final calls = <MethodCall>[];

  void answer(Future<Object?> Function(MethodCall call)? handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (handler == null) return null;
      return handler(call);
    });
  }

  setUp(calls.clear);
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  test('selecting a city asks the platform for that city', () async {
    answer((_) async => null);
    expect(await CityIcon().select('lisboa'), isTrue);
    expect(calls.single.method, 'select');
    expect(calls.single.arguments, {'city': 'lisboa'});
  });

  test('going back to the default sends null, not an empty string', () async {
    // An empty string would look up an asset named `AppIcon-` and fail on iOS.
    answer((_) async => null);
    await CityIcon().select(null);
    expect(calls.single.arguments, {'city': null});
  });

  test('a platform refusal is reported, never swallowed', () async {
    // A rider who taps an icon and sees nothing happen will tap it again. Returning false is what
    // lets the caller say "could not change it" instead of pretending.
    answer((_) async => throw PlatformException(code: 'unsupported'));
    expect(await CityIcon().select('bogota'), isFalse);
  });

  test('a desktop build does not pretend it has a home screen', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(CityIcon.supported, isFalse);
    expect(await CityIcon().select('bogota'), isFalse);
    expect(calls, isEmpty);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  test('a platform with no implementation at all is simply not supported', () async {
    answer((_) async => throw MissingPluginException());
    expect(await CityIcon().select('bogota'), isFalse);
    expect(await CityIcon().current(), isNull);
  });

  test('the current icon comes back as a city id, and the default as null', () async {
    answer((call) async => call.method == 'current' ? 'roma' : null);
    expect(await CityIcon().current(), 'roma');
    answer((_) async => null);
    expect(await CityIcon().current(), isNull);
  });
}
