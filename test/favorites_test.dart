import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/providers.dart';
import 'package:opentransit_mobile/core/storage/favorites.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const stop = Stop(
    id: 'bogota:PN',
    code: 'PN1',
    name: 'Portal Norte',
    position: LatLng(4.7546, -74.0459),
    locationType: 'station',
    component: Component.trunk,
  );
  const route = RouteRef(
    id: 'bogota:B10',
    shortName: 'B10',
    longName: 'Portal Norte - Portal Sur',
    color: '#D32F2F',
    textColor: '#FFFFFF',
    mode: TravelMode.bus,
    agencyId: '1',
    component: Component.trunk,
  );

  test('repository round-trips favorites', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = FavoritesRepository(prefs);
    expect(repo.load(), isEmpty);
    await repo.save([Favorite.stop('bogota', stop), Favorite.route('bogota', route)]);
    final again = FavoritesRepository(await SharedPreferences.getInstance()).load();
    expect(again, hasLength(2));
    expect(again.first.type, FavoriteType.stop);
    expect(again.first.position, stop.position);
    expect(again.last.color, '#D32F2F');
    expect(again.first.toPlace().stopId, 'bogota:PN');
  });

  test('corrupt storage degrades to empty', () async {
    SharedPreferences.setMockInitialValues({'favorites.v1': '{not json'});
    final prefs = await SharedPreferences.getInstance();
    expect(FavoritesRepository(prefs).load(), isEmpty);
  });

  test('notifier toggles and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);
    final n = container.read(favoritesProvider.notifier);
    final f = Favorite.stop('bogota', stop);
    expect(n.contains(f), isFalse);
    await n.toggle(f);
    expect(container.read(favoritesProvider), hasLength(1));
    expect(FavoritesRepository(prefs).load(), hasLength(1));
    await n.toggle(f);
    expect(container.read(favoritesProvider), isEmpty);
    await n.toggle(f);
    await n.remove(f);
    expect(FavoritesRepository(prefs).load(), isEmpty);
  });

  test('settings notifier persists preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);
    final n = container.read(settingsProvider.notifier);
    await n.setCity('bogota');
    await n.setWheelchair(true);
    await n.setMaxWalkDistance(900);
    expect(container.read(settingsProvider).cityId, 'bogota');
    final fresh = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
    addTearDown(fresh.dispose);
    final s = fresh.read(settingsProvider);
    expect(s.cityId, 'bogota');
    expect(s.wheelchair, isTrue);
    expect(s.maxWalkDistance, 900);
  });
}
