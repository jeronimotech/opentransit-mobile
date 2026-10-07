import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/city_icon.dart';
import '../../../core/models/models.dart';
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
    final citiesAsync = ref.watch(citiesProvider);
    final all = citiesAsync.asData?.value ?? const <City>[];
    // The rider's own city comes first, ahead of the default, because the question this row asks
    // is "which city", not "which colour" — and the answer most people want is the one they live
    // in. Finding it eleventh in an alphabetical list is what made it read as a palette.
    final home = ref.watch(settingsProvider).cityId;
    final cities = [
      ...all.where((c) => c.id == home),
      ...all.where((c) => c.id != home),
    ];
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
        // Without the city list there is nothing to choose from, and rendering just "Default" looks
        // like the feature works and offers one option. It cost a real test: the city list was
        // failing to load and the picker silently showed a single swatch.
        if (cities.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: citiesAsync.isLoading
                ? const SizedBox(
                    height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.errorOffline, style: TextStyle(color: scheme.onSurfaceVariant)),
          )
        else
        SizedBox(
          height: 76,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final c in cities) ...[
                _Swatch(
                  key: ValueKey('app-icon-${c.id}'),
                  label: c.name,
                  // Named as theirs, so the row reads as a list of cities rather than of colours.
                  hint: c.id == home ? l10n.appIconYourCity : null,
                  color: colorFromHex(c.primaryColor),
                  selected: current == c.id,
                  onTap: () => pick(c.id),
                ),
                if (c.id == home)
                  _Swatch(
                    key: const ValueKey('app-icon-default'),
                    label: l10n.appIconDefault,
                    color: scheme.outlineVariant,
                    selected: current == null,
                    onTap: () => pick(null),
                  ),
              ],
              // No city loaded means no home city either; the default still has to be reachable.
              if (cities.every((c) => c.id != home))
                _Swatch(
                  key: const ValueKey('app-icon-default'),
                  label: l10n.appIconDefault,
                  color: scheme.outlineVariant,
                  selected: current == null,
                  onTap: () => pick(null),
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
  const _Swatch({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.hint,
  });
  final String label;

  /// "Your city", under the rider's own. Nothing under the others.
  final String? hint;
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
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: hint != null ? FontWeight.w700 : FontWeight.w400)),
                ),
                if (hint != null)
                  SizedBox(
                    width: 56,
                    child: Text(hint!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
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
