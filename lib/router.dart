import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config.dart';
import 'core/providers.dart';
import 'features/alerts/alerts_screen.dart';
import 'features/cities/city_picker_screen.dart';
import 'features/favorites/favorites_screen.dart';
import 'features/home/app_shell.dart';
import 'features/home/home_screen.dart';
import 'features/live/vehicle_detail_screen.dart';
import 'features/planner/itinerary_detail_screen.dart';
import 'features/planner/place_search_screen.dart';
import 'features/planner/plan_screen.dart';
import 'features/planner/results_screen.dart';
import 'features/routes/route_detail_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/stops/stop_detail_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final uri = state.uri;
      final cityId = ref.read(settingsProvider).cityId;

      // Deep link `opentransit://bogota/plan?...` → `/bogota/plan?...`
      if (uri.scheme == AppConfig.deepLinkScheme && uri.host.isNotEmpty) {
        return Uri(path: '/${uri.host}${uri.path}', queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters).toString();
      }
      final segs = uri.pathSegments;
      if (segs.isEmpty) return cityId == null ? '/cities' : '/$cityId';
      if (segs.first == 'cities') return null;
      // Host-less deep link (`/plan?...`) → prefix with the remembered city.
      const known = {'plan', 'search', 'results', 'stops', 'routes', 'alerts', 'favorites', 'settings', 'vehicles', 'itinerary'};
      if (known.contains(segs.first)) {
        if (cityId == null) return '/cities';
        return Uri(path: '/$cityId${uri.path}', queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters).toString();
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/cities',
        builder: (_, _) => const CityPickerScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell, state: state),
        branches: [
          // go_router forbids a parameterised default location per branch, so
          // each branch declares a placeholder; AppShell always navigates with
          // an explicit `/{city}/...` location instead of `goBranch`.
          StatefulShellBranch(initialLocation: '/-', routes: [
            GoRoute(
              path: '/:city',
              builder: (_, s) => HomeScreen(cityId: s.pathParameters['city']!),
              routes: [
                GoRoute(
                  path: 'plan',
                  builder: (_, s) => PlanScreen(
                    cityId: s.pathParameters['city']!,
                    query: s.uri.queryParameters,
                  ),
                ),
                GoRoute(
                  path: 'search',
                  builder: (_, s) => PlaceSearchScreen(
                    cityId: s.pathParameters['city']!,
                    field: s.uri.queryParameters['field'] ?? 'to',
                  ),
                ),
                GoRoute(
                  path: 'results',
                  builder: (_, s) => ResultsScreen(cityId: s.pathParameters['city']!),
                ),
                GoRoute(
                  path: 'itinerary/:index',
                  builder: (_, s) => ItineraryDetailScreen(
                    cityId: s.pathParameters['city']!,
                    index: int.tryParse(s.pathParameters['index'] ?? '') ?? 0,
                  ),
                ),
                GoRoute(
                  path: 'stops/:stopId',
                  builder: (_, s) => StopDetailScreen(
                    cityId: s.pathParameters['city']!,
                    stopId: s.pathParameters['stopId']!,
                  ),
                ),
                GoRoute(
                  path: 'routes/:routeId',
                  builder: (_, s) => RouteDetailScreen(
                    cityId: s.pathParameters['city']!,
                    routeId: s.pathParameters['routeId']!,
                  ),
                ),
                GoRoute(
                  path: 'vehicles/:vehicleId',
                  builder: (_, s) => VehicleDetailScreen(
                    cityId: s.pathParameters['city']!,
                    vehicleId: s.pathParameters['vehicleId']!,
                  ),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(initialLocation: '/-/favorites', routes: [
            GoRoute(
              path: '/:city/favorites',
              builder: (_, s) => FavoritesScreen(cityId: s.pathParameters['city']!),
            ),
          ]),
          StatefulShellBranch(initialLocation: '/-/alerts', routes: [
            GoRoute(
              path: '/:city/alerts',
              builder: (_, s) => AlertsScreen(cityId: s.pathParameters['city']!),
            ),
          ]),
          StatefulShellBranch(initialLocation: '/-/settings', routes: [
            GoRoute(
              path: '/:city/settings',
              builder: (_, s) => SettingsScreen(cityId: s.pathParameters['city']!),
            ),
          ]),
        ],
      ),
    ],
  );
});
