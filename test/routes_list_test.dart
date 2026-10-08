library;

/// Which routes the list shows.
///
/// The rule worth protecting is a negative one: it must not drop a route because another shares its
/// number. This filter used to de-duplicate on short name + component, and Boston's thirty-eight
/// "Red Line Shuttle" routes go to thirty-eight different places.
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/features/routes/routes_screen.dart';

RouteRef _r(String id, String short, String long, {Component? component}) => RouteRef(
      id: id,
      shortName: short,
      longName: long,
      color: '#D32F2F',
      textColor: '#FFFFFF',
      mode: TravelMode.bus,
      agencyId: '1',
      component: component,
    );

void main() {
  final boston = [
    _r('a', 'Red Line Shuttle', 'JFK/UMass - Broadway'),
    _r('b', 'Red Line Shuttle', 'Ashmont - JFK/UMass'),
    _r('c', 'Red Line Shuttle', 'Quincy Center - Broadway'),
    _r('d', '1', 'Harvard - Nubian'),
  ];

  test('routes sharing a number all survive, because they go to different places', () {
    // The whole point. Three shuttles, three destinations, three rows.
    expect(visibleRoutes(boston).length, 4);
    expect(
      visibleRoutes(boston).map((r) => r.longName),
      containsAll(['JFK/UMass - Broadway', 'Ashmont - JFK/UMass', 'Quincy Center - Broadway']),
    );
  });

  test('the component filter narrows without dropping duplicates', () {
    final mixed = [
      _r('a', '9-3', 'Portal Sur', component: Component.feeder),
      _r('b', '9-3', 'Portal Americas', component: Component.feeder),
      _r('c', '9-3', 'Troncal', component: Component.trunk),
    ];
    expect(visibleRoutes(mixed, component: Component.feeder).length, 2);
    expect(visibleRoutes(mixed, component: Component.trunk).length, 1);
  });

  group('search', () {
    test('matches the number or the destination', () {
      expect(visibleRoutes(boston, query: 'ashmont').length, 1);
      expect(visibleRoutes(boston, query: 'red line').length, 3);
      expect(visibleRoutes(boston, query: 'harvard').single.shortName, '1');
    });

    test('ignores punctuation a rider would not type', () {
      final r = [_r('a', '9-3', 'Portal Sur')];
      expect(visibleRoutes(r, query: '93').length, 1);
      expect(visibleRoutes(r, query: '9-3').length, 1);
      expect(normaliseForSearch('Red Line'), 'redline');
    });

    test('an empty query shows everything', () {
      expect(visibleRoutes(boston, query: '   ').length, 4);
    });

    test('no match is an empty list, not everything', () {
      expect(visibleRoutes(boston, query: 'zzz'), isEmpty);
    });
  });
}
