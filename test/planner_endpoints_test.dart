// Contract addendum v2.1 — "choosing where a trip starts and ends".
//
// Covers the rules that are testable without a platform map: both ends are
// always reachable, no filled field is silently overwritten, swap survives an
// empty field, labels reach the router, and a street never renders as a
// station. Shapes are checked against the ones the live API actually sends
// (see the `photon:` rows in assets/fixtures/geocode.json).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/api/mock_api_client.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/providers.dart';
import 'package:opentransit_mobile/features/planner/place_search_screen.dart';
import 'package:opentransit_mobile/features/planner/plan_screen.dart';
import 'package:opentransit_mobile/features/planner/planner_actions.dart';
import 'package:opentransit_mobile/features/planner/planner_state.dart';
import 'package:opentransit_mobile/features/planner/widgets/place_result_tile.dart';
import 'package:opentransit_mobile/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fixtures.dart';

final _mock = MockApiClient(
    bundle: DiskAssetBundle(),
    now: DateTime.parse('2026-09-04T08:00:00-05:00'),
    latency: Duration.zero);

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({'city': 'bogota'});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [
    sharedPrefsProvider.overrideWithValue(prefs),
    apiClientProvider.overrideWithValue(_mock),
  ]);
}

Place _p(String name, [double lat = 4.6, double lon = -74.1]) =>
    Place(name: name, position: LatLng(lat, lon));

Widget _app(ProviderContainer c, Widget child, {Locale locale = const Locale('es')}) =>
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: child),
      ),
    );

void main() {
  _goNavigationGuards();
  TestWidgetsFlutterBinding.ensureInitialized();

  group('both ends are reachable', () {
    test('PlaceField.parse defaults to the destination but honours "from"', () {
      expect(PlaceField.parse('from'), PlaceField.from);
      expect(PlaceField.parse('to'), PlaceField.to);
      expect(PlaceField.parse(null), PlaceField.to);
      expect(PlaceField.from.other, PlaceField.to);
      expect(PlaceField.to.other, PlaceField.from);
    });

    test('an implicit pick never overwrites a filled field', () {
      const empty = PlannerState();
      expect(implicitTarget(empty, PlaceField.to), PlaceField.to);
      expect(implicitTarget(empty, PlaceField.from), PlaceField.from);

      // Destination already set, origin empty: the obvious action fills the
      // origin instead of clobbering the destination.
      final withTo = PlannerState(to: _p('Portal Norte'));
      expect(implicitTarget(withTo, PlaceField.to), PlaceField.from);

      final withFrom = PlannerState(from: _p('Calle 85'));
      expect(implicitTarget(withFrom, PlaceField.from), PlaceField.to);

      // Both filled: the field the UI was opened for wins (an explicit edit).
      final both = PlannerState(from: _p('a'), to: _p('b'));
      expect(implicitTarget(both, PlaceField.from), PlaceField.from);
      expect(implicitTarget(both, PlaceField.to), PlaceField.to);
    });

    test('placeOf reads the right end', () {
      final s = PlannerState(from: _p('A'), to: _p('B'));
      expect(placeOf(s, PlaceField.from)!.name, 'A');
      expect(placeOf(s, PlaceField.to)!.name, 'B');
    });

    testWidgets('assignPlace reports whether the trip can be planned now',
        (tester) async {
      final c = await _container();
      addTearDown(c.dispose);
      late WidgetRef ref;
      await tester.pumpWidget(_app(
          c, Consumer(builder: (_, r, _) {
            ref = r;
            return const SizedBox();
          })));
      await tester.pump();

      // One end alone cannot be planned.
      expect(assignPlace(ref, PlaceField.to, _p('Portal Norte')), isFalse);
      expect(c.read(plannerProvider).to!.name, 'Portal Norte');
      // This one completes the pair.
      expect(assignPlace(ref, PlaceField.from, _p('Calle 85')), isTrue);
      // Replacing an end of a plannable trip re-plans too: choosing a new origin
      // means you want that trip. Dragging a pin already behaves this way, and so
      // does the web client; the two clients must not diverge here.
      expect(assignPlace(ref, PlaceField.from, _p('Calle 100')), isTrue);
      expect(c.read(plannerProvider).from!.name, 'Calle 100');
    });
  });

  group('swap', () {
    test('exchanges both ends and keeps time, modes and on-demand', () async {
      final c = await _container();
      addTearDown(c.dispose);
      final n = c.read(plannerProvider.notifier);
      final when = DateTime(2026, 9, 8, 9);
      n.setFrom(_p('A'));
      n.setTo(_p('B'));
      n.setTime(when);
      n.setArriveBy(true);
      n.setOnDemand(true);
      n.swap();
      final s = c.read(plannerProvider);
      expect(s.from!.name, 'B');
      expect(s.to!.name, 'A');
      expect(s.time, when);
      expect(s.arriveBy, isTrue);
      expect(s.onDemand, isTrue);
    });

    test('survives one field being empty, in both directions', () async {
      final c = await _container();
      addTearDown(c.dispose);
      final n = c.read(plannerProvider.notifier);

      n.setTo(_p('B'));
      n.swap();
      expect(c.read(plannerProvider).from!.name, 'B');
      expect(c.read(plannerProvider).to, isNull);
      expect(c.read(plannerProvider).canPlan, isFalse);

      n.swap();
      expect(c.read(plannerProvider).from, isNull);
      expect(c.read(plannerProvider).to!.name, 'B');
    });

    test('swapping an empty form is a no-op, not a crash', () async {
      final c = await _container();
      addTearDown(c.dispose);
      c.read(plannerProvider.notifier).swap();
      expect(c.read(plannerProvider).from, isNull);
      expect(c.read(plannerProvider).to, isNull);
    });
  });

  group('labels reach the router', () {
    test('toQuery carries fromName / toName', () {
      final q = PlanRequest(from: _p('Calle 85'), to: _p('Portal Norte')).toQuery();
      expect(q['fromName'], 'Calle 85');
      expect(q['toName'], 'Portal Norte');
      expect(q['fromLat'], '4.6');
    });

    test('a nameless endpoint sends no label rather than an empty one', () {
      final q = PlanRequest(from: _p(''), to: _p('  ')).toQuery();
      expect(q.containsKey('fromName'), isFalse);
      expect(q.containsKey('toName'), isFalse);
    });

    test('the map picker location names the field and the point', () {
      final u = Uri.parse(pickOnMapLocation('bogota', PlaceField.from,
          at: const LatLng(4.6818705, -74.0749344)));
      expect(u.path, '/bogota/pick');
      expect(u.queryParameters['field'], 'from');
      expect(u.queryParameters['lat'], '4.6818705');
      expect(u.queryParameters['lon'], '-74.0749344');
      // Without a point the picker falls back to the field / position / city.
      expect(Uri.parse(pickOnMapLocation('medellin', PlaceField.to))
          .queryParameters
          .containsKey('lat'),
          isFalse);
    });
  });

  group('geocode results as the live API sends them', () {
    // The live shape: photon rows carry `component: null`, so a station cannot
    // be recognised by its colour — only by its id / type.
    GeocodeResult parse(String json) =>
        GeocodeResult.fromJson(jsonDecode(json) as Map<String, dynamic>);

    test('a street is not a stop', () {
      final r = parse('{"id":"photon:W90708869","name":"Calle 85",'
          '"label":"Localidad Barrios Unidos, Bogotá","lat":4.6818705,'
          '"lon":-74.0749344,"type":"street","stopId":null,"component":null,'
          '"source":"photon","distanceMeters":null}');
      expect(r.isStop, isFalse);
      expect(r.source, 'photon');
      expect(r.label, 'Localidad Barrios Unidos, Bogotá');
      expect(r.distanceMeters, isNull);
      expect(r.toPlace().stopId, isNull);
    });

    test('a station with a null component is still a stop', () {
      final r = parse('{"id":"stop:bogota:2303","name":"Calle 85 - Gato Dumas",'
          '"label":"Estación","lat":4.6715,"lon":-74.0598,"type":"station",'
          '"stopId":"bogota:2303","component":null,"source":"gtfs",'
          '"distanceMeters":420}');
      expect(r.isStop, isTrue);
      expect(r.distanceMeters, 420);
      expect(r.toPlace().stopId, 'bogota:2303');
    });

    test('addresses and POIs parse and stay non-stops', () {
      for (final t in ['address', 'poi', 'place']) {
        final r = parse('{"id":"photon:x","name":"n","label":"l","lat":1,'
            '"lon":2,"type":"$t","source":"photon"}');
        expect(r.isStop, isFalse, reason: t);
        expect(r.type, t);
      }
    });

    test('the mock feed offers places, not only GTFS stops', () async {
      final res = await _mock.geocode('bogota', 'Calle 85');
      expect(res, isNotEmpty);
      final all = await _mock.geocode('bogota', '', limit: 50);
      expect(all.where((r) => r.source == 'photon'), isNotEmpty,
          reason: 'the mock must emit the address/street/POI rows the live API sends');
      expect(all.map((r) => r.type).toSet(),
          containsAll(<String>['station', 'street', 'address', 'poi']));
    });
  });

  group('a street never looks like a station', () {
    testWidgets('the stop badge and the place badge are different widgets',
        (tester) async {
      final c = await _container();
      addTearDown(c.dispose);

      await tester.pumpWidget(_app(
        c,
        Column(children: [
          PlaceResultTile(
            tileKey: const ValueKey('t-street'),
            name: 'Calle 85',
            type: 'street',
            label: 'Localidad Barrios Unidos, Bogotá',
            defaultField: PlaceField.to,
            onPick: (_) {},
          ),
          PlaceResultTile(
            tileKey: const ValueKey('t-station'),
            name: 'Portal Norte',
            type: 'station',
            label: 'Estación · PN',
            component: Component.trunk,
            defaultField: PlaceField.to,
            onPick: (_) {},
          ),
        ]),
      ));
      await tester.pump();

      // The street row carries the place badge, the station row the stop badge.
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('t-street')),
              matching: find.byKey(const ValueKey('place-icon-place'))),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('t-street')),
              matching: find.byKey(const ValueKey('place-icon-stop'))),
          findsNothing);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('t-station')),
              matching: find.byKey(const ValueKey('place-icon-stop'))),
          findsOneWidget);

      // Icons differ too, and the result's own label is shown.
      expect(find.byIcon(Icons.signpost_outlined), findsOneWidget);
      expect(find.text('Localidad Barrios Unidos, Bogotá'), findsOneWidget);
      expect(find.text('Estación · PN'), findsOneWidget);
    });

    testWidgets('a labelless result falls back to its type, localised',
        (tester) async {
      final c = await _container();
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(
        c,
        PlaceResultTile(
          name: 'Sin etiqueta',
          type: 'address',
          defaultField: PlaceField.to,
          onPick: (_) {},
        ),
      ));
      await tester.pump();
      expect(find.text('Dirección'), findsOneWidget);
    });

    testWidgets('every result offers both origin and destination',
        (tester) async {
      final c = await _container();
      addTearDown(c.dispose);
      final picked = <PlaceField>[];
      await tester.pumpWidget(_app(
        c,
        PlaceResultTile(
          tileKey: const ValueKey('t'),
          name: 'Calle 85',
          type: 'street',
          // Opened for the destination…
          defaultField: PlaceField.to,
          onPick: picked.add,
        ),
      ));
      await tester.pump();

      // …so a plain tap fills the destination.
      await tester.tap(find.text('Calle 85'));
      expect(picked, [PlaceField.to]);

      // …and the origin is one tap away, never hidden.
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Usar como origen'), findsOneWidget);
      expect(find.text('Usar como destino'), findsOneWidget);
      await tester.tap(find.text('Usar como origen'));
      await tester.pumpAndSettle();
      expect(picked, [PlaceField.to, PlaceField.from]);
    });
  });

  group('the planner form offers both ends the same way', () {
    testWidgets('each field has my-location and choose-on-map, plus one swap',
        (tester) async {
      final c = await _container();
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, const PlanScreen(cityId: 'bogota')));
      await tester.pumpAndSettle();

      final from = find.byKey(const ValueKey('field-from'));
      final to = find.byKey(const ValueKey('field-to'));
      expect(from, findsOneWidget);
      expect(to, findsOneWidget);

      for (final field in [from, to]) {
        expect(
            find.descendant(of: field, matching: find.byIcon(Icons.my_location)),
            findsOneWidget);
        expect(
            find.descendant(of: field, matching: find.byIcon(Icons.map_outlined)),
            findsOneWidget);
      }
      // One swap control, and it is live on an empty-ish form (UX audit: no
      // control appears twice on the same screen).
      expect(find.byKey(const ValueKey('swap-places')), findsOneWidget);
      expect(
          tester
              .widget<IconButton>(find.byKey(const ValueKey('swap-places')))
              .onPressed,
          isNull,
          reason: 'nothing to swap while both ends are empty');

      c.read(plannerProvider.notifier).setTo(_p('Portal Norte'));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<IconButton>(find.byKey(const ValueKey('swap-places')))
              .onPressed,
          isNotNull,
          reason: 'swap must work with one field empty');
    });
  });

  group('the search list offers the map and the position for either field', () {
    testWidgets('origin search heads the list with both entry points',
        (tester) async {
      final c = await _container();
      addTearDown(c.dispose);
      await tester.pumpWidget(
          _app(c, const PlaceSearchScreen(cityId: 'bogota', field: 'from')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('search-my-location')), findsOneWidget);
      expect(find.byKey(const ValueKey('search-choose-on-map')), findsOneWidget);
      expect(find.text('Elegir en el mapa'), findsOneWidget);
      // Both rows say which end they fill, and offer the other end too.
      expect(find.text('Origen'), findsWidgets);
      expect(find.byKey(const ValueKey('search-choose-on-map-other')), findsOneWidget);
      expect(find.byKey(const ValueKey('search-my-location-other')), findsOneWidget);
    });

    testWidgets('a bare search deep link fills the empty end, not the full one',
        (tester) async {
      final c = await _container();
      addTearDown(c.dispose);
      // Destination already chosen; the generic search must offer the origin.
      c.read(plannerProvider.notifier).setTo(_p('Portal Norte'));
      await tester.pumpWidget(_app(
          c,
          // `implicit: true` is what the router passes for `/city/search`
          // without a `field` query parameter.
          const PlaceSearchScreen(cityId: 'bogota', field: 'to', implicit: true)));
      await tester.pumpAndSettle();

      // Every row targets the empty end by default...
      expect(find.text('Origen'), findsWidgets);
      // ...while the filled end stays reachable, but only as the named secondary
      // action, so it can be replaced deliberately and never by accident.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('search-my-location-other')),
          matching: find.text('Destino'),
        ),
        findsOneWidget,
      );
      // The destination is untouched.
      expect(c.read(plannerProvider).to!.name, 'Portal Norte');
    });

    testWidgets('geocoded streets and stops render differently in the list',
        (tester) async {
      final c = await _container();
      addTearDown(c.dispose);
      // Fixture files are read with real IO, which FakeAsync never drains, so
      // the mock's cache is warmed first.
      await tester.runAsync(() async {
        await _mock.cities();
        await _mock.geocode('bogota', 'Calle 85');
      });
      // The city provider is then resolved on the fake clock (awaiting it
      // inside runAsync would deadlock), so the screen's own
      // `ref.read(cityProvider(...).future)` completes on a plain pump.
      unawaited(c.read(cityProvider('bogota').future));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pumpWidget(
          _app(c, const PlaceSearchScreen(cityId: 'bogota', field: 'to')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Calle 85');
      // The 300 ms debounce, then the mock's reply. Not pumpAndSettle: the
      // in-flight LinearProgressIndicator animates forever.
      await tester.pump(const Duration(milliseconds: 400));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byType(PlaceResultTile), findsWidgets);
      // The street row from the fixture is present and carries the place badge.
      expect(find.text('Localidad Barrios Unidos, Bogotá'), findsOneWidget);
      expect(find.byKey(const ValueKey('place-icon-place')), findsWidgets);
    });
  });

  group('localisation', () {
    testWidgets('the new strings exist in es and en', (tester) async {
      for (final locale in const [Locale('es'), Locale('en')]) {
        late AppLocalizations l10n;
        await tester.pumpWidget(MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(builder: (ctx) {
            l10n = AppLocalizations.of(ctx);
            return const SizedBox();
          }),
        ));
        await tester.pump();
        final strings = <String>[
          l10n.chooseOnMap,
          l10n.setAsOrigin,
          l10n.setAsDestination,
          l10n.pickOnMapHint,
          l10n.pickOnMapSearching,
          l10n.pickOnMapConfirmOrigin,
          l10n.pickOnMapConfirmDestination,
          l10n.dragPinsHint,
          l10n.replanning,
          l10n.replanFailed,
          l10n.placeOptions,
          for (final t in ['station', 'stop', 'address', 'street', 'poi'])
            placeTypeLabel(t, l10n),
        ];
        for (final s in strings) {
          expect(s.trim(), isNotEmpty, reason: '$locale');
        }
        // Confirming the origin and the destination must not read the same.
        expect(l10n.pickOnMapConfirmOrigin,
            isNot(l10n.pickOnMapConfirmDestination));
        expect(placeTypeLabel('street', l10n),
            isNot(placeTypeLabel('station', l10n)));
      }
    });

    testWidgets('Spanish uses the strings the contract names', (tester) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(builder: (ctx) {
          l10n = AppLocalizations.of(ctx);
          return const SizedBox();
        }),
      ));
      await tester.pump();
      expect(l10n.setAsOrigin, 'Usar como origen');
      expect(l10n.setAsDestination, 'Usar como destino');
      expect(l10n.chooseOnMap, 'Elegir en el mapa');
    });
  });

  // The drag chain is four links long and every one is silent when it breaks:
  // the platform view only builds a CircleManager when `annotationOrder` names
  // circles; that manager only listens for drags when `annotationConsumeTapEvents`
  // names them too (its default does, so overriding it would break drag without
  // a single warning); iOS hit-tests the `draggable` attribute on the feature;
  // and the flag is `late final`, so the map must be built with pins already in
  // hand. Verified against maplibre_gl 0.27 sources; pin it so a refactor cannot
  // quietly leave a pin that looks draggable and is not.
  group('draggable pins stay wired', () {
    String read(String path) => File(path).readAsStringSync();

    test('the map opts circles into annotations and into interaction', () {
      final map = read('lib/core/widgets/transit_map.dart');
      expect(map, contains('annotationOrder: _draggable ? const [ml.AnnotationType.circle] : const []'));
      expect(map, contains('draggable: true'));
      expect(map, contains('onFeatureDrag.add(_onFeatureDrag)'));
      expect(map, contains('onFeatureDrag.remove(_onFeatureDrag)'));
      expect(
        map.contains('annotationConsumeTapEvents'),
        isFalse,
        reason: 'the default already includes circle; overriding it silently kills the drag',
      );
    });

    test('the itinerary map is only built once it has pins to draw', () {
      final screen = read('lib/features/planner/itinerary_detail_screen.dart');
      // `_draggable` is decided on first build, so an early build with no pins
      // would disable dragging for the life of the screen.
      expect(screen.indexOf('_pins = ['), lessThan(screen.indexOf('draggableMarkers: _pins!')));
      expect(screen, contains('onMarkerDragEnd: _onPinDropped'));
    });
  });
}

// GO: recalculating must keep you navigating, and the camera must behave like a
// navigation view rather than an overview that refits on every GPS fix.
void _goNavigationGuards() {
  group('GO navigation', () {
    String read(String path) => File(path).readAsStringSync();

    test('a replan keeps following instead of ejecting you', () {
      final go = read('lib/features/planner/follow_along_screen.dart');
      // It used to `context.pop()` after replanning, which threw someone mid-walk
      // back to the itinerary screen and read as "it did not recalculate".
      expect(go, contains("router.pushReplacement('/\${widget.cityId}/itinerary/0/go')"));
      expect(go, isNot(contains('await planner.plan(widget.cityId);\n    if (mounted) context.pop();')));
      // A failed replan leaves the current trip on screen rather than nothing.
      expect(go, contains('goReplanFailed'));
    });

    test('the map navigates and yields the camera to a gesture', () {
      final go = read('lib/features/planner/follow_along_screen.dart');
      expect(go, contains('navigating: !_denied && !_arrived'));
      expect(go, contains('onTrackingDismissed'));
      expect(go, contains("ValueKey('go-recenter')"));

      final map = read('lib/core/widgets/transit_map.dart');
      // Following the device with the heading up is what makes it a navigation view.
      expect(map, contains('MyLocationTrackingMode.trackingGps'));
      expect(map, contains('MyLocationRenderMode.gps'));
      // Refitting bounds every fix would fight the follow camera.
      expect(map, contains('if (!widget.navigating &&'));
      // Tracking resumes only when the screen asks, never on its own.
      expect(map, contains('widget.recenterSignal != oldWidget.recenterSignal'));
    });
  });
}
