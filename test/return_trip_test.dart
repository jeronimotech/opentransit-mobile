library;

/// Planning the way back.
///
/// Reported by TransMilenio against 1.16.0: "invertir" replanned with the outbound hour, so asking
/// for the way home at six in the evening planned it for the eight in the morning you left at.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:opentransit_mobile/core/providers.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/features/planner/planner_state.dart';

Place _p(String name, double lat) => Place(name: name, position: LatLng(lat, -74.08));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer c;
  PlannerNotifier n() => c.read(plannerProvider.notifier);
  PlannerState s() => c.read(plannerProvider);

  setUp(() async {
    // toggleMode records analytics, which reads preferences.
    SharedPreferences.setMockInitialValues({'city': 'bogota'});
    final prefs = await SharedPreferences.getInstance();
    c = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
    n().setFrom(_p('Portal Suba', 4.74));
    n().setTo(_p('Av Jiménez', 4.60));
    n().setTime(DateTime(2026, 10, 9, 8, 0));
  });
  tearDown(() => c.dispose());

  test('a return reverses the endpoints', () {
    n().planReturn(at: DateTime(2026, 10, 9, 18, 0));
    expect(s().from!.name, 'Av Jiménez');
    expect(s().to!.name, 'Portal Suba');
  });

  test('and takes its own hour, not the outbound one', () {
    // The bug: this used to stay at 08:00.
    n().planReturn(at: DateTime(2026, 10, 9, 18, 0));
    expect(s().time, DateTime(2026, 10, 9, 18, 0));
  });

  test('null means now, which the planner reads as no fixed time', () {
    n().planReturn();
    expect(s().time, isNull);
  });

  test('a return is a departure, never an arrival', () {
    // Carrying "arrive by" over would ask for a trip home that *arrives* at the hour you wanted to
    // reach work — a different trip entirely, and one nobody asked for.
    n().setArriveBy(true);
    n().planReturn(at: DateTime(2026, 10, 9, 18, 0));
    expect(s().arriveBy, isFalse);
  });

  test('it keeps the modes and options the rider chose', () {
    n().toggleMode(TravelMode.bicycle);
    final modes = s().modes;
    n().planReturn();
    expect(s().modes, modes);
  });

  test('swap still keeps the time, because it is for a different mistake', () {
    // Swap exists to correct a pair entered the wrong way round, where the hour is still the one
    // the rider meant. Making both behave the same would fix one complaint and cause another.
    n().swap();
    expect(s().time, DateTime(2026, 10, 9, 8, 0));
    expect(s().from!.name, 'Av Jiménez');
  });

  test('a return drops the previous result rather than showing it under new endpoints', () {
    n().planReturn();
    expect(s().result, isNull);
  });
}
