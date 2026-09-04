import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

enum HomeAction { plan, locate, routes }

/// The three compact actions in the home sheet's peek row (UX audit §A):
/// Planear viaje · Ubica tu bus · Buscar ruta. Everything else lives in the
/// bottom nav or on the map itself.
class HomeActionChips extends StatelessWidget {
  const HomeActionChips({super.key, required this.actions, required this.onTap});
  final List<HomeAction> actions;
  final void Function(HomeAction) onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _Chip(
              key: ValueKey('hub-${actions[i].name}'),
              icon: _icon(actions[i]),
              label: _label(actions[i], l10n),
              primary: actions[i] == HomeAction.plan,
              scheme: scheme,
              onTap: () => onTap(actions[i]),
            ),
          ),
        ],
      ],
    );
  }

  static IconData _icon(HomeAction a) => switch (a) {
        HomeAction.plan => Icons.alt_route_rounded,
        HomeAction.locate => Icons.directions_bus_rounded,
        HomeAction.routes => Icons.route_rounded,
      };

  static String _label(HomeAction a, AppLocalizations l10n) => switch (a) {
        HomeAction.plan => l10n.actionPlan,
        HomeAction.locate => l10n.actionLocate,
        HomeAction.routes => l10n.actionRoutes,
      };
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.scheme,
    this.primary = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme scheme;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final bg = primary ? scheme.primary : scheme.surfaceContainerHigh;
    final fg = primary ? scheme.onPrimary : scheme.onSurface;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: primary ? fg : scheme.primary, size: 17),
                const SizedBox(width: 5),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label,
                        maxLines: 1,
                        style: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
