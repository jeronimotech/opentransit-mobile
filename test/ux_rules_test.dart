// v1.1.1 "map first" rules: route chip colour blending, headsign clean-up and
// zoom → vehicle marker style.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/live/marker_style.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/utils/colors.dart';
import 'package:opentransit_mobile/core/utils/text.dart';

RouteRef _route(String color, {String text = '#FFFFFF', Component c = Component.trunk}) => RouteRef(
      id: 'bogota:x', shortName: 'X', longName: 'X', color: color, textColor: text,
      mode: TravelMode.bus, agencyId: '1', component: c);

void main() {
  group('route chip colours', () {
    test('neon feed colour falls back to the component colour', () {
      final c = routeChipColors(_route('#FF0000'));
      expect(c.bg, componentColor(Component.trunk));
      expect(contrastRatio(c.bg, c.fg), greaterThanOrEqualTo(4.5));
    });

    test('non-neon feed colour is blended 35 % toward the component', () {
      const feed = Color(0xFF00A0E0);
      final comp = componentColor(Component.zonal);
      final c = routeChipColors(_route('#00A0E0', c: Component.zonal));
      final expected = ensureContrast(blendColors(feed, comp, 0.35), c.fg);
      expect(c.bg.toARGB32(), expected.toARGB32());
    });

    test('contrast with the text is at least 4.5:1', () {
      for (final hex in ['#FFFF00', '#CCCCCC', '#123456', '#00FF00', '#FF8800']) {
        final c = routeChipColors(_route(hex, text: '#FFFFFF', c: Component.feeder));
        expect(contrastRatio(c.bg, c.fg), greaterThanOrEqualTo(4.5), reason: hex);
      }
    });

    test('feed text colour that cannot reach contrast is replaced', () {
      final c = routeChipColors(_route('#FFFF00', text: '#FFFFFF'));
      expect(c.fg, isNot(Colors.white));
    });

    test('desaturate keeps hue and reduces saturation', () {
      const red = Color(0xFFD32F2F);
      final d = desaturate(red, 0.2);
      expect(HSLColor.fromColor(d).saturation, lessThan(HSLColor.fromColor(red).saturation));
      expect(HSLColor.fromColor(d).hue, closeTo(HSLColor.fromColor(red).hue, 1));
    });
  });

  group('headsign clean-up', () {
    test('splits on || and renders an arrow', () {
      expect(cleanHeadsign('Andalucía ||  Portal Norte'), 'Andalucía → Portal Norte');
    });
    test('splits on " - " and en dash, title-cases ALL CAPS', () {
      expect(cleanHeadsign('P. SUR - PORTAL NORTE'), 'P. Sur → Portal Norte');
      expect(cleanHeadsign('Nueva Roma – Portal Sur'), 'Nueva Roma → Portal Sur');
    });
    test('keeps hyphenated codes and short tokens', () {
      expect(cleanHeadsign('Portal Norte 2-11'), 'Portal Norte 2-11');
      expect(cleanHeadsign('PORTAL NORTE T4'), 'Portal Norte T4');
    });
    test('headsignLabel: "Hacia X" for one destination, bare "A → B" otherwise', () {
      String hacia(String x) => 'Hacia $x';
      expect(headsignLabel('Portal Sur', towards: hacia), 'Hacia Portal Sur');
      expect(headsignLabel('Verbenal || Portal Norte', towards: hacia), 'Verbenal → Portal Norte');
      expect(headsignLabel('  ', towards: hacia), isNull);
      expect(headsignLabel(null, towards: hacia), isNull);
    });
    test('empty and null → null', () {
      expect(cleanHeadsign(null), isNull);
      expect(cleanHeadsign('  '), isNull);
      expect(cleanHeadsign('||'), isNull);
    });
  });

  group('vehicle marker style by zoom', () {
    test('hidden below 14, small 14–16, large at 16+', () {
      expect(vehicleMarkerStyle(12).mode, VehicleMarkerMode.hidden);
      expect(vehicleMarkerStyle(13.9).visible, isFalse);
      expect(vehicleMarkerStyle(14).mode, VehicleMarkerMode.small);
      expect(vehicleMarkerStyle(15.9).showBearing, isFalse);
      expect(vehicleMarkerStyle(16).mode, VehicleMarkerMode.large);
      expect(vehicleMarkerStyle(17).showBearing, isTrue);
    });
    test('a selected route keeps vehicles visible at any zoom', () {
      final s = vehicleMarkerStyle(11, selected: true);
      expect(s.visible, isTrue);
      expect(s.opacity, 1);
    });
    test('network line: neon feed colour → component, translucent', () {
      final comp = componentColor(Component.zonal);
      final neon = networkLineColor('#0000FF', comp);
      final custom = networkLineColor('#00A0E0', comp);
      expect(HSLColor.fromColor(neon).hue, closeTo(HSLColor.fromColor(comp).hue, 1));
      expect(neon.a, closeTo(0.5, 0.01));
      expect(networkLineColor('#0000FF', comp, backbone: false).a, closeTo(0.18, 0.01));
      expect(HSLColor.fromColor(custom).hue, closeTo(HSLColor.fromColor(const Color(0xFF00A0E0)).hue, 1));
    });
    test('map colours are desaturated unless selected', () {
      const c = Color(0xFF6A1B9A);
      expect(mapVehicleColor(c, selected: true), c);
      expect(mapVehicleColor(c), isNot(c));
    });
  });
}
