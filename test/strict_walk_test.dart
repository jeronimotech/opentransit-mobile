library;

/// The walking limit as a limit (1.11).
///
/// The setting used to lower the router's walking reluctance, so a rider who said 500 m still got
/// options with a kilometre of walking.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/providers.dart';
import 'package:opentransit_mobile/features/planner/widgets/plan_warnings.dart';
import 'package:opentransit_mobile/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

Place _p(String name, double lat) => Place(name: name, position: LatLng(lat, -74.08));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the query carries the cap only when the rider asked for one', () {
    final req = PlanRequest(from: _p('a', 4.6), to: _p('b', 4.7), maxWalkDistance: 500);
    expect(req.toQuery()['maxWalkDistance'], '500');
    expect(req.toQuery().containsKey('strictWalk'), isFalse);

    final strict = PlanRequest(from: _p('a', 4.6), to: _p('b', 4.7), maxWalkDistance: 500, strictWalk: true);
    expect(strict.toQuery()['strictWalk'], 'true');
  });

  test('the switch is off by default and persists', () async {
    SharedPreferences.setMockInitialValues({'city': 'bogota'});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    expect(c.read(settingsProvider).strictWalkLimit, isFalse);
    await c.read(settingsProvider.notifier).setStrictWalkLimit(true);
    expect(prefs.getBool('strictWalkLimit'), isTrue);
  });

  test('the rider is told when the cap removed options', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('es'));
    // A filter that silently empties the list is indistinguishable from "no service".
    final line = PlanWarnings.line(l10n, 'WALK_LIMIT_FILTERED: 2 of 5 options walked further');
    expect(line, isNotNull);
    expect(line, contains('límite'));
  });
}
