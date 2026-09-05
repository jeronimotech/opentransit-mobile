// v1.4 on-demand mobility: provider/tariff/leg parsing, price formatting and
// range, provider ordering, hand-off platform parameter, chip gating by feature
// flag, taxi tariff estimate, and the provider picker widget.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

    test('openHandoff tries the link, then the fallback, and reports what opened', () async {
      final tried = <String>[];
      Future<bool> failFirst(Uri u) async {
        tried.add(u.toString());
        return !u.host.contains('api.example.org');
      }
      final r = await openHandoff(
        handoffUrl: 'https://api.example.org/h?providerId=x',
        fallback: Uri.parse('https://apps.apple.com/app/x'),
        platform: 'ios',
        launcher: failFirst,
      );
      expect(r, 'fallback');
      expect(tried.first, contains('platform=ios'));
      expect(await openHandoff(handoffUrl: null, fallback: null, launcher: failFirst), 'none');
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
    testWidgets('renders rows, prices or "Precio en la app", and requests through the hand-off', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final opened = <String>[];
      final requested = <String>[];
      final od = plans.first.legs.single.onDemand!;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          apiClientProvider.overrideWithValue(MockApiClient(bundle: DiskAssetBundle(), latency: Duration.zero)),
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
      expect(find.byKey(const ValueKey('ondemand-provider-taxi')), findsOneWidget);
      expect(find.text('Precio en la app'), findsNWidgets(4));
      expect(find.textContaining('≈'), findsOneWidget);
      expect(find.text('Recomendado'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ondemand-request-uber')));
      await tester.pumpAndSettle();
      expect(opened.single, contains('providerId=uber'));
      expect(opened.single, contains('platform='));
      expect(requested, ['uber:link']);
    });
  });
}
