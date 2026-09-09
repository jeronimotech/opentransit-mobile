import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/widgets/common.dart';
import 'package:opentransit_mobile/features/home/widgets/layers_button.dart';
import 'package:opentransit_mobile/l10n/generated/app_localizations.dart';

import 'helpers/fixtures.dart';

/// The two network layers are named after the city's own components, and every component has to
/// land in one of them: `tram` and `bus` fell in neither, so the TTC's streetcars and buses were
/// never drawn, and the toggles read "Rutas zonales" in Toronto.
void main() {
  City cityWith(List<String> componentIds) {
    final json = Map<String, dynamic>.from(loadFixture('cities')['cities'][0] as Map);
    json['components'] = [
      for (final id in componentIds) {'id': id, 'label': id, 'color': '#000000'},
    ];
    return City.fromJson(json);
  }

  group('component grouping', () {
    test('every component is drawn in exactly one layer', () {
      for (final c in Component.values) {
        expect(c.isBackbone, isA<bool>(), reason: '${c.name} must belong to a group');
      }
      final backbone = Component.values.where((c) => c.isBackbone).toSet();
      final rest = Component.values.where((c) => !c.isBackbone).toSet();
      expect(backbone.union(rest), Component.values.toSet());
      expect(backbone.intersection(rest), isEmpty);
    });

    test('a streetcar is backbone, a bus is not', () {
      expect(Component.tram.isBackbone, isTrue);
      expect(Component.bus.isBackbone, isFalse);
      expect(Component.trunk.isBackbone, isTrue);
      expect(Component.zonal.isBackbone, isFalse);
    });
  });

  group('layerComponents', () {
    test('splits each city with its own vocabulary, in declared order', () {
      final bogota = cityWith(['trunk', 'feeder', 'dual', 'zonal', 'cable']);
      expect(bogota.layerComponents(backbone: true), [Component.trunk, Component.cable]);
      expect(bogota.layerComponents(backbone: false),
          [Component.feeder, Component.dual, Component.zonal]);

      final toronto = cityWith(['rail', 'tram', 'bus']);
      expect(toronto.layerComponents(backbone: true), [Component.rail, Component.tram]);
      expect(toronto.layerComponents(backbone: false), [Component.bus]);
    });

    test('is empty when the city has nothing there, so the toggle is dropped', () {
      expect(cityWith(['bus']).layerComponents(backbone: true), isEmpty);
      expect(cityWith(['rail']).layerComponents(backbone: false), isEmpty);
    });

    test('falls back to the components the agencies use when the city declares none', () {
      final json = Map<String, dynamic>.from(loadFixture('cities')['cities'][0] as Map);
      json.remove('components');
      final city = City.fromJson(json);
      expect(city.componentIds, contains(Component.trunk));
      expect(city.layerComponents(backbone: true), contains(Component.trunk));
    });
  });

  group('networkLayerLabel', () {
    testWidgets('joins the city\'s own component labels', (tester) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (ctx) {
          l10n = AppLocalizations.of(ctx);
          return const SizedBox();
        }),
      ));

      final toronto = City.fromJson({
        ...Map<String, dynamic>.from(loadFixture('cities')['cities'][0] as Map),
        'components': [
          {'id': 'rail', 'label': 'Subway', 'color': '#DA291C'},
          {'id': 'tram', 'label': 'Streetcar', 'color': '#0054A6'},
          {'id': 'bus', 'label': 'Bus', 'color': '#DA291C'},
        ],
      });
      expect(networkLayerLabel(toronto, l10n, backbone: true), 'Subway · Streetcar');
      expect(networkLayerLabel(toronto, l10n, backbone: false), 'Bus');

      // a city that declares no label for tram/bus still gets a real word, not "Other"
      final bare = City.fromJson({
        ...Map<String, dynamic>.from(loadFixture('cities')['cities'][0] as Map),
        'components': [
          {'id': 'tram', 'label': '', 'color': '#000000'},
          {'id': 'bus', 'label': '', 'color': '#000000'},
        ],
      });
      expect(networkLayerLabel(bare, l10n, backbone: true), 'Streetcar');
      expect(networkLayerLabel(bare, l10n, backbone: false), 'Bus');
    });

    testWidgets('is null for a group the city has nothing in', (tester) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (ctx) {
          l10n = AppLocalizations.of(ctx);
          return const SizedBox();
        }),
      ));
      final busOnly = City.fromJson({
        ...Map<String, dynamic>.from(loadFixture('cities')['cities'][0] as Map),
        'components': [
          {'id': 'bus', 'label': 'Bus', 'color': '#000000'},
        ],
      });
      expect(networkLayerLabel(busOnly, l10n, backbone: true), isNull);
      expect(networkLayerLabel(busOnly, l10n, backbone: false), 'Bus');
    });
  });

  group('the layers popover', () {
    Future<void> open(WidgetTester tester, {String? network, String? zonal}) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LayersButton(
            layers: const MapLayers(live: true, pois: true, network: true),
            networkLabel: network,
            zonalLabel: zonal,
            onChanged: (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
    }

    testWidgets('titles the toggles with the city\'s own components', (tester) async {
      await open(tester, network: 'Subway · Streetcar', zonal: 'Bus');
      expect(find.text('Subway · Streetcar'), findsOneWidget);
      expect(find.text('Bus'), findsOneWidget);
      // the old copy named Bogotá's network in every city
      expect(find.text('Zonal routes'), findsNothing);
      expect(find.text('Route network'), findsNothing);
    });

    testWidgets('drops a toggle the city has nothing to draw in', (tester) async {
      await open(tester, network: 'Subway', zonal: null);
      expect(find.byKey(const ValueKey('layer-network')), findsOneWidget);
      expect(find.byKey(const ValueKey('layer-zonal')), findsNothing);
    });
  });
}
