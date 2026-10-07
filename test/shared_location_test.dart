library;

/// Reading a place someone shared from another app. Every shape here is one a real app sends;
/// `geo:0,0?q=…(Name)` in particular is what Google Maps hands to a `geo:` handler, and reading its
/// `0,0` as a coordinate would drop every shared pin in the Gulf of Guinea.
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/utils/links.dart';
import 'package:opentransit_mobile/core/utils/shared_location.dart';

void main() {
  group('geo: URIs', () {
    test('a plain pair is the point', () {
      final s = parseSharedLocation('geo:4.6010,-74.0718')!;
      expect(s.isPoint, isTrue);
      expect(s.position!.lat, closeTo(4.6010, 1e-9));
      expect(s.position!.lon, closeTo(-74.0718, 1e-9));
      expect(s.name, isNull);
    });

    test('a zoom parameter does not confuse the body', () {
      final s = parseSharedLocation('geo:43.6532,-79.3832?z=17')!;
      expect(s.position!.lat, closeTo(43.6532, 1e-9));
    });

    test('0,0 is a placeholder for q, not the null island', () {
      // What Google Maps actually sends. Trusting the body here is the bug this test exists for.
      final s = parseSharedLocation('geo:0,0?q=4.6010,-74.0718(Museo del Oro)')!;
      expect(s.position!.lat, closeTo(4.6010, 1e-9));
      expect(s.position!.lon, closeTo(-74.0718, 1e-9));
      expect(s.name, 'Museo del Oro');
    });

    test('a name with no coordinates becomes a search, not a failure', () {
      final s = parseSharedLocation('geo:0,0?q=Museo del Oro')!;
      expect(s.isPoint, isFalse);
      expect(s.query, 'Museo del Oro');
    });

    test('nothing usable at all is null', () {
      expect(parseSharedLocation('geo:0,0'), isNull);
      expect(parseSharedLocation('geo:0,0?q='), isNull);
      expect(parseSharedLocation(''), isNull);
      expect(parseSharedLocation('   '), isNull);
    });
  });

  group('map links', () {
    test('a Google Maps place link reads the @ pair and the name', () {
      final s = parseSharedLocation(
          'https://www.google.com/maps/place/Museo+del+Oro/@4.6010,-74.0718,17z/data=!3m1')!;
      expect(s.position!.lat, closeTo(4.6010, 1e-9));
      expect(s.name, 'Museo del Oro');
    });

    test('a Google Maps query link reads the pair', () {
      final s = parseSharedLocation('https://www.google.com/maps/search/?api=1&query=4.601,-74.072')!;
      expect(s.position!.lon, closeTo(-74.072, 1e-9));
    });

    test('an Apple Maps link reads ll and q', () {
      final s = parseSharedLocation('https://maps.apple.com/?ll=43.6532,-79.3832&q=Union+Station')!;
      expect(s.position!.lat, closeTo(43.6532, 1e-9));
      expect(s.name, 'Union Station');
    });

    test('an OpenStreetMap link reads the fragment', () {
      final s = parseSharedLocation('https://www.openstreetmap.org/#map=17/4.6010/-74.0718')!;
      expect(s.position!.lat, closeTo(4.6010, 1e-9));
    });

    test('a shortlink is admitted as unreadable rather than guessed', () {
      // Resolving it needs an HTTP redirect, and this parser does no network. A wrong pin is worse
      // than telling the rider the link could not be read.
      expect(parseSharedLocation('https://maps.app.goo.gl/AbCdEf123'), isNull);
      expect(parseSharedLocation('https://goo.gl/maps/AbCdEf123'), isNull);
    });

    test('a link that is not a map is not a location', () {
      expect(parseSharedLocation('https://example.com/4.60,-74.07'), isNull);
      expect(parseSharedLocation('https://news.site/article/2024,2025'), isNull);
    });
  });

  group('shared text', () {
    test('a link inside a sentence is found', () {
      final s = parseSharedLocation('Nos vemos acá https://maps.apple.com/?ll=4.601,-74.072 dale')!;
      expect(s.position!.lat, closeTo(4.601, 1e-9));
    });

    test('trailing punctuation does not become part of the link', () {
      final s = parseSharedLocation('aquí: https://www.openstreetmap.org/#map=16/4.601/-74.072.')!;
      expect(s.position!.lon, closeTo(-74.072, 1e-9));
    });

    test('a bare pair pasted on its own works', () {
      final s = parseSharedLocation('4.6010, -74.0718')!;
      expect(s.position!.lat, closeTo(4.6010, 1e-9));
      expect(s.name, isNull);
    });
  });

  group('where a shared place lands in the app', () {
    String? location(String raw) {
      final where = parseSharedLocation(raw);
      return where == null ? null : CanonicalLinks.forSharedLocation(where);
    }

    test('a point opens the planner with the destination filled', () {
      final loc = Uri.parse(location('geo:0,0?q=4.6010,-74.0718(Museo del Oro)')!);
      expect(loc.path, '/plan');
      expect(loc.queryParameters['toLat'], '4.601');
      expect(loc.queryParameters['toLon'], '-74.0718');
      expect(loc.queryParameters['toName'], 'Museo del Oro');
    });

    test('a nameless point carries no empty label', () {
      final loc = Uri.parse(location('geo:4.6010,-74.0718')!);
      // An empty `toName` would show the rider a blank destination field with a filled pin.
      expect(loc.queryParameters.containsKey('toName'), isFalse);
    });

    test('a name with no coordinates opens place search, already typed', () {
      final loc = Uri.parse(location('geo:0,0?q=Museo del Oro')!);
      expect(loc.path, '/search');
      expect(loc.queryParameters['q'], 'Museo del Oro');
      expect(loc.queryParameters['field'], 'to');
    });

    test('the city is left out, because only the router knows which one covers the point', () {
      // `cityForPosition` needs the loaded city list; keeping this pure keeps it testable.
      expect(Uri.parse(location('geo:43.6532,-79.3832')!).path, '/plan');
    });
  });

  group('the whole path a geo: intent takes', () {
    test('toAppLocation reads a geo: URI end to end', () {
      final loc = CanonicalLinks.toAppLocation(Uri.parse('geo:4.6010,-74.0718'));
      expect(Uri.parse(loc!).queryParameters['toLat'], '4.601');
    });

    test('a share repackaged by MainActivity reads end to end', () {
      // Exactly what the Kotlin side builds: opentransit://shared?text=<the shared text>.
      final shared = Uri(
        scheme: 'opentransit',
        host: 'shared',
        queryParameters: {'text': 'Nos vemos acá https://maps.apple.com/?ll=4.601,-74.072'},
      );
      final loc = CanonicalLinks.toAppLocation(shared);
      expect(Uri.parse(loc!).path, '/plan');
      expect(Uri.parse(loc).queryParameters['toLat'], '4.601');
    });

    String? share(String text) => CanonicalLinks.toAppLocation(
        Uri(scheme: 'opentransit', host: 'shared', queryParameters: {'text': text}));

    test('an address shared as plain text goes to place search', () {
      // Claiming ACTION_SEND puts us in the share sheet for any text, so the alternative is
      // opening the home screen and doing nothing visible with what someone deliberately sent.
      final loc = Uri.parse(share('Calle 72 #10-34, Bogotá')!);
      expect(loc.path, '/search');
      expect(loc.queryParameters['q'], 'Calle 72 #10-34, Bogotá');
    });

    test('a link we could not read is not treated as an address', () {
      // A shortlink needs the network; handing its characters to a geocoder finds nothing and
      // looks like the app misunderstood rather than like the link was unreadable.
      expect(share('https://maps.app.goo.gl/AbCdEf123'), isNull);
    });

    test('an article is not a place', () {
      expect(share('x' * 200), isNull);
      expect(share('line one\nline two'), isNull);
      expect(share('ok'), isNull);
      expect(share(''), isNull);
    });

    test('the existing city deep links still work', () {
      // `shared` is a reserved host now; a real city must not be caught by it.
      expect(CanonicalLinks.toAppLocation(Uri.parse('opentransit://bogota/plan?toLat=1')),
          '/bogota/plan?toLat=1');
    });
  });

  group('numbers that are not coordinates', () {
    test('out-of-range pairs are rejected instead of clamped', () {
      // A price range or a date reads as "two numbers with a comma". Clamping would pin it.
      expect(parseSharedLocation('91.0, -74.0'), isNull);
      expect(parseSharedLocation('45.0, 181.0'), isNull);
      expect(parseSharedLocation('1200, 1500'), isNull);
    });

    test('a single number is not a pair', () {
      expect(parseSharedLocation('4.6010'), isNull);
      expect(parseSharedLocation('geo:4.6010'), isNull);
    });
  });
}
