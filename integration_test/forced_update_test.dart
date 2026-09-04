// Screenshot cue for the forced-update screen: overrides the mock city so
// `config.minAppVersion` is above the running version.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:opentransit_mobile/app.dart';
import 'package:opentransit_mobile/core/api/mock_api_client.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mock whose Bogotá requires app version 9.9.9.
class _StrictMock extends MockApiClient {
  @override
  Future<List<City>> cities() async => [
        for (final c in await super.cities())
          City(
            id: c.id, name: c.name, country: c.country, timezone: c.timezone, locale: c.locale,
            center: c.center, bbox: c.bbox, defaultZoom: c.defaultZoom, modes: c.modes,
            primaryColor: c.primaryColor, features: c.features, agencies: c.agencies,
            attribution: c.attribution, components: c.components, fares: c.fares, links: c.links,
            services: c.services,
            config: const CityConfig(minAppVersionIos: '9.9.9', minAppVersionAndroid: '9.9.9'),
          ),
      ];
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('forced update screen', (tester) async {
    SharedPreferences.setMockInitialValues({'city': 'bogota', 'locale': 'es'});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      apiClientProvider.overrideWithValue(_StrictMock()),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const OpenTransitApp()));
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('forced-update')), findsOneWidget);
    expect(find.text('Actualiza la app'), findsOneWidget);
    // ignore: avoid_print
    print('SCREENSHOT:12_forced_update');
    await Future<void>.delayed(const Duration(seconds: 4));
    await tester.pump();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
