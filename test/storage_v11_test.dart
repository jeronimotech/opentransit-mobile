import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/providers.dart';
import 'package:opentransit_mobile/core/storage/favorites.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const place = Place(name: 'Cra 45 # 174-20', position: LatLng(4.756, -74.044));

  group('typed favorites', () {
    test('home/work are singletons per city and round-trip with kind + icon', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
      addTearDown(container.dispose);
      final n = container.read(favoritesProvider.notifier);
      await n.put(Favorite.place('bogota', place, kind: FavoriteKind.home, icon: 'home', name: 'Casa'));
      await n.put(Favorite.place('bogota', const Place(name: 'Otra', position: LatLng(4.7, -74.0)), kind: FavoriteKind.home, icon: 'home', name: 'Casa'));
      await n.put(Favorite.place('bogota', place, kind: FavoriteKind.custom, icon: 'school', name: 'Uni'));
      final all = container.read(favoritesProvider);
      expect(all.where((f) => f.kind == FavoriteKind.home), hasLength(1), reason: 'second put replaced the first');
      expect(n.ofKind('bogota', FavoriteKind.home)!.subtitle, 'Otra');
      expect(n.ofKind('medellin', FavoriteKind.home), isNull);
      final again = FavoritesRepository(prefs).load();
      final uni = again.firstWhere((f) => f.name == 'Uni');
      expect(uni.kind, FavoriteKind.custom);
      expect(uni.icon, 'school');
      expect(uni.toPlace().position, place.position);
    });

    test('legacy favorites without kind parse as custom', () {
      final f = Favorite.fromJson({'type': 'place', 'cityId': 'bogota', 'id': 'p', 'name': 'x', 'lat': 1, 'lon': 2});
      expect(f.kind, FavoriteKind.custom);
      expect(f.icon, isNull);
    });
  });

  group('recent trips', () {
    test('keeps the last 10, most recent first, de-duplicated', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
      addTearDown(container.dispose);
      final n = container.read(recentTripsProvider.notifier);
      for (var i = 0; i < 12; i++) {
        await n.add(RecentTrip(
          cityId: 'bogota',
          from: Place(name: 'A$i', position: LatLng(4 + i / 100, -74)),
          to: place,
          at: DateTime(2026, 1, 1, 8, i),
        ));
      }
      expect(container.read(recentTripsProvider), hasLength(10));
      expect(container.read(recentTripsProvider).first.from.name, 'A11');
      // re-adding an existing pair moves it to the front without duplicating
      await n.add(RecentTrip(cityId: 'bogota', from: Place(name: 'A5', position: const LatLng(4.05, -74)), to: place, at: DateTime(2026, 1, 2)));
      final list = container.read(recentTripsProvider);
      expect(list.first.from.name, 'A5');
      expect(list.where((t) => t.from.name == 'A5'), hasLength(1));
      expect(RecentTripsRepository(prefs).load(), hasLength(10));
      await n.clear('bogota');
      expect(container.read(recentTripsProvider), isEmpty);
    });
  });

  group('alert impressions', () {
    test('caps impressions at 3 and honours dismiss', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = AlertImpressionsRepository(prefs);
      expect(repo.shouldShow('a'), isTrue);
      await repo.recordImpression('a');
      await repo.recordImpression('a');
      expect(repo.shouldShow('a'), isTrue);
      await repo.recordImpression('a');
      expect(repo.impressions('a'), 3);
      expect(repo.shouldShow('a'), isFalse);
      expect(repo.shouldShow('b'), isTrue);
      await repo.dismiss('b');
      expect(repo.shouldShow('b'), isFalse);
      await repo.prune(['b']);
      expect(repo.impressions('a'), 0, reason: 'pruned');
    });

    test('notifier counts one impression per session and persists dismissals', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
      addTearDown(container.dispose);
      final n = container.read(alertImpressionsProvider.notifier);
      await n.recordImpression('x');
      await n.recordImpression('x');
      expect(AlertImpressionsRepository(prefs).impressions('x'), 1);
      await n.dismiss('x');
      expect(n.shouldShow('x'), isFalse);
      expect(AlertImpressionsRepository(prefs).isDismissed('x'), isTrue);
    });
  });
}
