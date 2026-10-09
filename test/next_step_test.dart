library;

/// The guided trip's "next step" line.
///
/// Asked for by TransMilenio against 1.16.0: the card said what to do now, "tramo 2 de 4" and the
/// arrival time, so a rider learned that leg 3 was a 400 m walk only once leg 2 ended.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/utils/leg_steps.dart';
import 'package:opentransit_mobile/l10n/generated/app_localizations.dart';

import 'helpers/factories.dart';

void main() {
  late AppLocalizations es;
  late AppLocalizations en;

  setUpAll(() async {
    es = await AppLocalizations.delegate.load(const Locale('es'));
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  final legs = [
    leg(toName: 'Portal Suba'),
    leg(mode: TravelMode.bus, transit: true, route: routeRef(shortName: 'B74'), fromName: 'Portal Suba', toName: 'Av Chile'),
    leg(fromName: 'Av Chile', toName: 'Calle 72'),
  ];

  test('the next step is the leg after the current one', () {
    expect(nextStepLabel(es, legs, 0), 'Luego: ${es.boardAt('Portal Suba')}');
    expect(nextStepLabel(es, legs, 1), 'Luego: ${es.walkTo('Calle 72')}');
  });

  test('the last leg announces the arrival instead', () {
    expect(nextStepLabel(es, legs, 2), es.nextStepArrive);
    expect(nextStepLabel(en, legs, 2), en.nextStepArrive);
  });

  test('a single-leg trip only has the arrival', () {
    expect(nextStepLabel(es, [legs.first], 0), es.nextStepArrive);
  });

  test('an index outside the trip has no next step', () {
    expect(nextStepLabel(es, legs, 3), isNull);
    expect(nextStepLabel(es, legs, -1), isNull);
    expect(nextStepLabel(es, const [], 0), isNull);
  });

  // The next leg is one you have not reached, so it always reads as where to board — never as
  // where to get off, which is what the current-action line says once you are on board.
  test('the next transit leg asks you to board, not to get off', () {
    final label = nextStepLabel(es, legs, 0)!;
    expect(label, contains('Portal Suba'));
    expect(label, isNot(contains('Av Chile')));
  });

  group('legInstruction', () {
    test('a transit leg flips on boarding', () {
      final l = legs[1];
      expect(legInstruction(es, l), es.boardAt('Portal Suba'));
      expect(legInstruction(es, l, boarded: true), es.getOffAt('Av Chile'));
    });

    test('a walk leg names where it ends', () {
      expect(legInstruction(es, legs[2]), es.walkTo('Calle 72'));
      // Walking is never "boarded", so the flag cannot change the wording.
      expect(legInstruction(es, legs[2], boarded: true), es.walkTo('Calle 72'));
    });
  });
}
