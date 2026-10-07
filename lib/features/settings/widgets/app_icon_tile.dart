import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/city_icon.dart';
import '../../../core/providers.dart';
import '../../../core/utils/colors.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Choose which city's colours the home-screen icon wears.
///
/// Opt-in and never automatic. Changing it is not free on either platform — Android kills the
/// process, iOS shows a system alert — so it happens because someone asked, not because they
/// switched city to look at a bus.
class AppIconTile extends ConsumerWidget {
  const AppIconTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!CityIcon.supported) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final cities = ref.watch(citiesProvider).asData?.value ?? const [];
    final current = ref.watch(currentCityIconProvider).asData?.value;

    Future<void> pick(String? city) async {
      final ok = await ref.read(cityIconProvider).select(city);
      ref.invalidate(currentCityIconProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? l10n.appIconChanged : l10n.appIconFailed)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Icons.apps_rounded),
          title: Text(l10n.appIconTitle),
          subtitle: Text(l10n.appIconExplain, style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
        SizedBox(
          height: 76,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _Swatch(
                key: const ValueKey('app-icon-default'),
                label: l10n.appIconDefault,
                color: scheme.outlineVariant,
                selected: current == null,
                onTap: () => pick(null),
              ),
              for (final c in cities)
                _Swatch(
                  key: ValueKey('app-icon-${c.id}'),
                  label: c.name,
                  color: colorFromHex(c.primaryColor),
                  selected: current == c.id,
                  onTap: () => pick(c.id),
                ),
            ],
          ),
        ),
        if (defaultTargetPlatform == TargetPlatform.android)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            // Said before the tap, not after: on Android the process dies as the icon changes, and
            // an app that vanishes without warning reads as a crash.
            child: Text(l10n.appIconAndroidNote,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, height: 1.3)),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({super.key, required this.label, required this.color, required this.selected, required this.onTap});
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(11),
                    border: selected ? Border.all(color: scheme.primary, width: 2.5) : null,
                  ),
                  child: selected
                      ? Icon(Icons.check_rounded, size: 20, color: _on(color))
                      : null,
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 56,
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A tick that stays visible on Lisboa's yellow as well as on Bogotá's red.
  static Color _on(Color bg) =>
      bg.computeLuminance() > 0.4 ? const Color(0xFF1A1A1A) : Colors.white;
}
