// v1.4 on-demand mobility: provider/tariff/leg parsing, price formatting and
// range, provider ordering, hand-off platform parameter, chip gating by feature
// flag, taxi tariff estimate, and the provider picker widget.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/api/api_client.dart';
import 'package:opentransit_mobile/core/api/mock_api_client.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/providers.dart';
import 'package:opentransit_mobile/core/utils/ondemand.dart';
import 'package:opentransit_mobile/features/ondemand/provider_picker.dart';
import 'package:opentransit_mobile/features/planner/results_screen.dart';
import 'package:opentransit_mobile/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fixtures.dart';

void main() {
  final cities = (loadFixture('cities')['cities'] as List)
      .map((e) => City.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  final bogota = cities.firstWhere((c) => c.id == 'bogota');
  final medellin = cities.firstWhere((c) => c.id == 'medellin');
  final plans = (loadFixture('plan_ondemand')['itineraries'] as List)
      .map((e) => Itinerary.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  final providers = (loadFixture('ondemand_providers')['providers'] as List)
      .map((e) => OnDemandProvider.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();

  group('city config', () {
    test('providers, tariffs and policy parse per city; N providers', () {
      expect(bogota.onDemandEnabled, isTrue);
      expect(bogota.mobility.onDemandProviders, hasLength(5));
      expect(bogota.mobility.onDemandProviders.first.isTaxi, isTrue);
      expect(bogota.mobility.taxiTariffs.single.flagFall, 4500);
      expect(bogota.mobility.taxiTariffs.single.surcharge('night')?.amount, 3800);
      expect(bogota.mobility.onDemandPolicy.maxFeederKm, 8);
      expect(medellin.mobility.onDemandProviders.map((p) => p.id), ['taxi', 'app-x']);
      expect(medellin.mobility.tariff('medellin-taxi-2026')?.minimumFare, 7500);
      expect(medellin.mobility.provider('app-x')?.web, 'https://example.org/ride-x');
    });

    test('public provider list carries hasTemplate but never a template or credentials', () {
      final uber = providers.firstWhere((p) => p.id == 'uber');
      expect(uber.hasTemplate, isTrue);
      expect(uber.handoffKind, 'template');
      final raw = (loadFixture('ondemand_providers')['providers'] as List).cast<Map>();
      for (final p in raw) {
        expect(p.containsKey('credentials'), isFalse);
        expect((p['handoff'] as Map).containsKey('template'), isFalse);
      }
    });

    test('feature flag, remote config and empty provider list all disable the chip', () {
      final noProviders = City.fromJson({'id': 'x', 'name': 'X', 'features': {'onDemand': true}});
      expect(noProviders.onDemandEnabled, isFalse);
      final flagOff = City.fromJson({
        'id': 'y', 'name': 'Y', 'features': {'onDemand': false},
        'mobility': {'onDemand': [{'id': 'a', 'name': 'A'}]},
      });
      expect(flagOff.onDemandEnabled, isFalse);
      final remoteOff = City.fromJson({
        'id': 'z', 'name': 'Z', 'features': {'onDemand': true},
        'config': {'features': {'onDemand': false}},
        'mobility': {'onDemand': [{'id': 'a', 'name': 'A'}]},
      });
      expect(remoteOff.onDemandEnabled, isFalse);
      final disabledProvider = City.fromJson({
        'id': 'w', 'name': 'W', 'features': {'onDemand': true},
        'mobility': {'onDemand': [{'id': 'a', 'name': 'A', 'enabled': false}]},
      });
      expect(disabledProvider.onDemandEnabled, isFalse);
    });

    test('chip label is generic with several providers, the name with one', () {
      expect(onDemandChipLabel(bogota, 'Taxi / app'), 'Taxi / app');
      final one = City.fromJson({
        'id': 'o', 'name': 'O', 'features': {'onDemand': true},
        'mobility': {'onDemand': [{'id': 'a', 'name': 'Solo Taxi'}]},
      });
      expect(onDemandChipLabel(one, 'Taxi / app'), 'Solo Taxi');
    });
  });

  group('legs and itineraries', () {
    test('direct ride: CAR leg with providers, recommended taxi, price band', () {
      final direct = plans.first;
      expect(direct.hasOnDemand, isTrue);
      expect(direct.isOnDemandDirect, isTrue);
      expect(direct.source, 'ondemand');
      final leg = direct.legs.single;
      expect(leg.mode, TravelMode.car);
      expect(leg.isOnDemand, isTrue);
      final od = leg.onDemand!;
      expect(od.kind, 'taxi');
      expect(od.providers, hasLength(5));
      expect(od.recommended?.providerId, 'taxi');
      expect(od.recommended?.price?.hasRange, isTrue);
      expect(od.recommended?.price?.min, lessThan(od.recommended!.price!.max!));
      expect(od.providers.where((p) => p.price == null), hasLength(4), reason: 'ride apps have no estimate');
      expect(leg.colorHex, '#F2C200');
    });

    test('combo: taxi first mile then bus; fare mixes kinds', () {
      final combo = plans[1];
      expect(combo.isOnDemandDirect, isFalse);
      expect(combo.legs.map((l) => l.isOnDemand ? 'ONDEMAND' : l.mode.wire), ['ONDEMAND', 'BUS', 'WALK']);
      expect(combo.fare!.breakdown.map((l) => l.kind), ['ondemand', 'transit']);
      expect(combo.fare!.breakdown.first.isOnDemand, isTrue);
    });

    test('fare with a null amount keeps the note', () {
      final f = Fare.fromJson({'amount': null, 'currency': 'COP', 'estimated': true, 'note': 'Precio en la app'});
      expect(f.hasAmount, isFalse);
      expect(f.note, 'Precio en la app');
    });

    test('"Más económico" sorts by ride estimate and puts unknown prices last', () async {
      final api = MockApiClient(bundle: DiskAssetBundle(), latency: Duration.zero);
      final res = await api.plan('bogota', PlanRequest(
        from: const Place(name: 'A', position: LatLng(4.7560, -74.0440)),
        to: const Place(name: 'B', position: LatLng(4.5990, -74.1600)),
        onDemand: true,
      ));
      expect(res.itineraries.where((i) => i.hasOnDemand), hasLength(2));
      final sorted = sortItineraries(res.itineraries, ItinerarySort.cheapest, city: bogota);
      // Transit-only 3,200 first; the taxi combo and the direct taxi after.
      expect(sorted.first.hasOnDemand, isFalse);
      expect(sorted.last.isOnDemandDirect, isTrue);
    });
  });

  group('prices and hand-off', () {
    test('range formatting collapses the repeated currency symbol', () {
      const p = OnDemandPrice(amount: 20000, min: 18000, max: 22000, currency: 'COP');
      expect(formatPriceRange(p, 'es_CO'), '≈ \$ 18.000–22.000');
      const single = OnDemandPrice(amount: 8000, currency: 'COP', estimated: false);
      expect(formatPriceRange(single, 'es_CO'), '\$ 8.000');
    });

    test('provider ordering: recommended, then priced ascending, then config order', () {
      final opts = [
        const OnDemandOption(providerId: 'indrive', name: 'I'),
        const OnDemandOption(providerId: 'cabify', name: 'C', price: OnDemandPrice(amount: 25000, currency: 'COP')),
        const OnDemandOption(providerId: 'taxi', name: 'T', price: OnDemandPrice(amount: 20000, currency: 'COP')),
        const OnDemandOption(providerId: 'uber', name: 'U'),
      ];
      expect(sortOptions(opts, recommendedId: 'cabify', city: bogota).map((o) => o.providerId),
          ['cabify', 'taxi', 'uber', 'indrive']);
      expect(sortOptions(opts, city: bogota).map((o) => o.providerId), ['taxi', 'cabify', 'uber', 'indrive']);
    });

    test('hand-off URL gets the platform parameter (added or replaced)', () {
      final u = handoffUri('https://api.example.org/v1/cities/bogota/ondemand/handoff?providerId=uber&fromLat=4.7', platform: 'ios');
      expect(u.queryParameters['platform'], 'ios');
      expect(u.queryParameters['providerId'], 'uber');
      final v = handoffUri('https://x/h?platform=web', platform: 'android');
      expect(v.queryParameters['platform'], 'android');
      expect(handoffPlatform(isIos: true), 'ios');
      expect(handoffPlatform(isIos: false, isAndroid: true), 'android');
    });

    test('fallback prefers the platform store link, then the website', () {
      final uber = providers.firstWhere((p) => p.id == 'uber');
      expect(providerFallbackLink(uber, isIos: true).toString(), uber.appIos);
      expect(providerFallbackLink(uber, isIos: false).toString(), uber.appAndroid);
      const webOnly = OnDemandProvider(id: 'w', name: 'W', web: 'https://w.example');
      expect(providerFallbackLink(webOnly, isIos: true).toString(), 'https://w.example');
      expect(providerFallbackLink(const OnDemandProvider(id: 'n', name: 'N'), isIos: true), isNull);
    });

    test('placeLabel drops generic OTP names; endpoint names come from the user', () {
      expect(placeLabel(const Place(name: 'Origin', position: LatLng(0, 0))), isNull);
      expect(placeLabel(const Place(name: 'destino', position: LatLng(0, 0))), isNull);
      expect(placeLabel(const Place(name: 'Portal Norte', position: LatLng(0, 0))), 'Portal Norte');
      final named = legsWithEndpointNames(plans.first, fromName: 'Casa', toName: 'Oficina');
      expect(named.single.from.name, 'Cra 45 # 174-20', reason: 'real names are kept');
      final generic = Itinerary.fromJson({
        ...loadFixture('plan_ondemand')['itineraries'][0] as Map,
        'legs': [
          {...(loadFixture('plan_ondemand')['itineraries'][0] as Map)['legs'][0] as Map,
            'from': {'name': 'Origin', 'lat': 4.7, 'lon': -74.0}, 'to': {'name': 'Destination', 'lat': 4.6, 'lon': -74.1}},
        ],
      });
      final fixed = legsWithEndpointNames(generic, fromName: 'Casa', toName: 'Oficina');
      expect(fixed.single.from.name, 'Casa');
      expect(fixed.single.to.name, 'Oficina');
    });

    test('requestRide fetches the hand-off JSON with names + platform and launches the provider URL, never the API', () async {
      final spy = _SpyApi();
      final launched = <String>[];
      final r = await requestRide(
        api: spy, cityId: 'bogota', providerId: 'uber',
        from: const Place(name: 'Portal Norte', position: LatLng(4.7546, -74.0459)),
        to: const Place(name: 'Origin', position: LatLng(4.5978, -74.1616)),
        platform: 'ios',
        launcher: (u) async { launched.add(u.toString()); return true; },
        canLaunch: (_) async => false,
      );
      expect(r, 'link');
      expect(spy.calls.single['providerId'], 'uber');
      expect(spy.calls.single['fromName'], 'Portal Norte');
      expect(spy.calls.single['toName'], isNull, reason: 'generic names are not prefilled');
      expect(spy.calls.single['platform'], 'ios');
      expect(launched.single, startsWith('https://m.uber.com/looking?'));
      expect(launched.single, isNot(contains('/ondemand/handoff')));
    });

    test('requestRide falls back to the store link when the provider URL cannot be opened', () async {
      final spy = _SpyApi();
      final launched = <String>[];
      final r = await requestRide(
        api: spy, cityId: 'bogota', providerId: 'uber',
        from: const Place(name: 'A', position: LatLng(4.7, -74.0)),
        to: const Place(name: 'B', position: LatLng(4.6, -74.1)),
        launcher: (u) async { launched.add(u.toString()); return !u.host.contains('m.uber.com'); },
      );
      expect(r, 'fallback');
      expect(launched, hasLength(2));
      expect(launched.last, 'https://apps.apple.com/co/app/id368677368');
    });

    test('requestRide uses the configured store/web link when the API call fails', () async {
      final spy = _SpyApi(fail: true);
      final launched = <String>[];
      final uber = providers.firstWhere((p) => p.id == 'uber');
      final r = await requestRide(
        api: spy, cityId: 'bogota', providerId: 'uber', provider: uber, platform: 'android',
        from: const Place(name: 'A', position: LatLng(4.7, -74.0)),
        to: const Place(name: 'B', position: LatLng(4.6, -74.1)),
        launcher: (u) async { launched.add(u.toString()); return true; },
      );
      expect(r, 'fallback');
      expect(launched.single, uber.appAndroid);
      expect(await requestRide(
        api: spy, cityId: 'bogota', providerId: 'nope',
        from: const Place(name: 'A', position: LatLng(4.7, -74.0)),
        to: const Place(name: 'B', position: LatLng(4.6, -74.1)),
        launcher: (_) async => true,
      ), 'none');
    });

    test('custom-scheme URLs are only launched when the app is installed', () async {
      final spy = _SpyApi(url: 'someapp://ride?x=1', fallback: 'https://example.org/store');
      final launched = <String>[];
      final r = await requestRide(
        api: spy, cityId: 'bogota', providerId: 'x',
        from: const Place(name: 'A', position: LatLng(4.7, -74.0)),
        to: const Place(name: 'B', position: LatLng(4.6, -74.1)),
        launcher: (u) async { launched.add(u.toString()); return true; },
        canLaunch: (_) async => false,
      );
      expect(r, 'fallback');
      expect(launched.single, 'https://example.org/store');
    });

    test('taxi tariff estimate: units, minimum, night surcharge, ±10 % band', () {
      final t = bogota.mobility.taxiTariffs.single;
      final day = DateTime(2026, 9, 4, 10); // Friday morning
      final short = estimateTaxiFare(t, 1200, 300, day)!;
      expect(short.amount, 8000, reason: 'below the minimum fare');
      final ride = estimateTaxiFare(t, 10000, 1200, day)!; // 100 distance units, no waiting → 4500 + 15900
      expect(ride.amount, 20400);
      expect(ride.min, 18400);
      expect(ride.max, 22400);
      expect(ride.surchargesApplied, isEmpty);
      final slow = estimateTaxiFare(t, 10000, 1500, day)!; // +300 s in traffic → 10 waiting units
      expect(slow.amount, 22000);
      final night = estimateTaxiFare(t, 10000, 1200, DateTime(2026, 9, 4, 22))!;
      expect(night.amount, 20400 + 3800);
      expect(night.surchargesApplied, ['night']);
      final sunday = estimateTaxiFare(t, 10000, 1200, DateTime(2026, 9, 6, 12))!;
      expect(sunday.surchargesApplied, ['night']);
      expect(isNightOrHoliday(DateTime(2026, 12, 25, 12), holidays: {'2026-12-25'}), isTrue);
    });
  });

  group('mock client', () {
    test('providers, estimate and hand-off; plan adds on-demand itineraries only when asked', () async {
      final api = MockApiClient(bundle: DiskAssetBundle(), latency: Duration.zero);
      final ps = await api.onDemandProviders('bogota');
      expect(ps, hasLength(5));
      expect(await api.onDemandProviders('medellin'), hasLength(2));
      final est = await api.onDemandEstimate('bogota', const LatLng(4.7560, -74.0440), const LatLng(4.5990, -74.1600));
      expect(est.estimates.where((e) => e.price != null), hasLength(1));
      expect(est.distanceMeters, greaterThan(15000));
      final h = await api.onDemandHandoff('bogota', 'uber', const LatLng(4.75, -74.04), const LatLng(4.6, -74.16), platform: 'ios');
      expect(h.url, isNotEmpty);
      expect(h.fallback, contains('apps.apple.com'));
      final plain = await api.plan('bogota', PlanRequest(
        from: const Place(name: 'A', position: LatLng(4.7560, -74.0440)),
        to: const Place(name: 'B', position: LatLng(4.5990, -74.1600)),
      ));
      expect(plain.itineraries.any((i) => i.hasOnDemand), isFalse);
    });
  });

  group('ProviderPicker widget', () {
    // Pre-warm the fixture cache OUTSIDE the widget test: the tap triggers a
    // hand-off fetch, and real file IO never completes under fake async.
    final api = MockApiClient(bundle: DiskAssetBundle(), latency: Duration.zero);
    setUpAll(() async {
      await api.onDemandProviders('bogota');
      await api.city('bogota');
    });

    testWidgets('renders rows, prices or "Precio en la app", and requests through the hand-off', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final opened = <String>[];
      final requested = <String>[];
      final od = plans.first.legs.single.onDemand!;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          apiClientProvider.overrideWithValue(api),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProviderPicker(
                cityId: 'bogota',
                from: const Place(name: 'Cra 45 # 174-20', position: LatLng(4.7560, -74.0440)),
                to: const Place(name: 'Cl 57 Sur # 75-10', position: LatLng(4.5990, -74.1600)),
                options: od.providers,
                recommendedId: od.recommendedProviderId,
                launcher: (u) async {
                  opened.add(u.toString());
                  return true;
                },
                onRequest: (o, what) => requested.add('${o.providerId}:$what'),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ondemand-picker')), findsOneWidget);
      // One primary button for the recommended provider with its price band…
      final primary = find.byKey(const ValueKey('ondemand-request-taxi'));
      expect(primary, findsOneWidget);
      expect(find.descendant(of: primary, matching: find.textContaining('Pedir Taxi · ≈')), findsOneWidget);
      // …then "O pide con:" and one pill per other provider (name only).
      expect(find.text('O pide con:'), findsOneWidget);
      for (final id in ['uber', 'cabify', 'didi', 'indrive']) {
        expect(find.byKey(ValueKey('ondemand-request-$id')), findsOneWidget);
      }
      expect(find.text('Precio en la app'), findsNothing);
      // Only one provider carries an estimate → no "Ver precios" expander.
      expect(find.byKey(const ValueKey('ondemand-prices-toggle')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('ondemand-request-uber')));
      await tester.pumpAndSettle();
      // The mock hand-off answers the provider's own web URL; the API endpoint is never opened.
      expect(opened.single, 'https://m.uber.com/');
      expect(opened.single, isNot(contains('/ondemand/handoff')));
      expect(requested, ['uber:link']);
    });

    testWidgets('"Ver precios" appears with 2+ estimates and its rows request the provider', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final opened = <String>[];
      final od = plans.first.legs.single.onDemand!;
      final options = [
        for (final o in od.providers)
          o.providerId == 'cabify'
              ? OnDemandOption(providerId: o.providerId, name: o.name, color: o.color, handoffUrl: o.handoffUrl, source: 'api',
                  price: const OnDemandPrice(amount: 60000, min: 55000, max: 65000, currency: 'COP'))
              : o,
      ];
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs), apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: const [
            AppLocalizations.delegate, GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProviderPicker(
                cityId: 'bogota',
                from: const Place(name: 'A', position: LatLng(4.7560, -74.0440)),
                to: const Place(name: 'B', position: LatLng(4.5990, -74.1600)),
                options: options,
                recommendedId: 'taxi',
                launcher: (u) async { opened.add(u.toString()); return true; },
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final toggle = find.byKey(const ValueKey('ondemand-prices-toggle'));
      expect(toggle, findsOneWidget);
      expect(find.byKey(const ValueKey('ondemand-price-row-cabify')), findsNothing);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ondemand-price-row-taxi')), findsOneWidget);
      expect(find.byKey(const ValueKey('ondemand-price-row-cabify')), findsOneWidget);
      expect(find.textContaining('55.000–65.000'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ondemand-price-row-cabify')));
      await tester.pumpAndSettle();
      expect(opened.single, 'https://cabify.com/co');
    });
  });
}

/// Records hand-off calls and answers a canned provider URL.
class _SpyApi extends MockApiClient {
  _SpyApi({this.fail = false, this.url = 'https://m.uber.com/looking?client_id=abc&pickup=%7B%7D', this.fallback = 'https://apps.apple.com/co/app/id368677368'})
      : super(bundle: DiskAssetBundle(), latency: Duration.zero);
  final bool fail;
  final String url;
  final String? fallback;
  final calls = <Map<String, Object?>>[];

  @override
  Future<OnDemandHandoff> onDemandHandoff(String cityId, String providerId, LatLng from, LatLng to,
      {String? fromName, String? toName, String platform = 'web'}) async {
    calls.add({'providerId': providerId, 'fromName': fromName, 'toName': toName, 'platform': platform});
    if (fail) throw const ApiException('NETWORK', 'offline');
    return OnDemandHandoff(url: url, fallback: fallback);
  }
}
