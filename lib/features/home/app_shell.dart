import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';

const _tabPaths = ['', '/favorites', '/alerts', '/settings'];

/// Bottom navigation shell. The bar is hidden on nested detail routes of the
/// home branch so maps and timelines get the full height.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell, required this.state});
  final StatefulNavigationShell shell;
  final GoRouterState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final segs = state.uri.pathSegments;
    final nested = shell.currentIndex == 0 && segs.length > 1;
    final city = state.pathParameters['city'] ?? (segs.isEmpty ? '' : segs.first);
    return Scaffold(
      body: shell,
      bottomNavigationBar: nested
          ? null
          : NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: (i) => context.go('/$city${_tabPaths[i]}'),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.map_outlined),
                  selectedIcon: const Icon(Icons.map),
                  label: l10n.home,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.star_outline),
                  selectedIcon: const Icon(Icons.star),
                  label: l10n.favorites,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.notifications_outlined),
                  selectedIcon: const Icon(Icons.notifications),
                  label: l10n.alerts,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: l10n.settings,
                ),
              ],
            ),
    );
  }
}
