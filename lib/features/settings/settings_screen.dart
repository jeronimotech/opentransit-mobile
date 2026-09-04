import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../l10n/generated/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, required this.cityId});
  final String cityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final city = ref.watch(cityProvider(cityId)).asData?.value;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          ListTile(
            leading: const Icon(Icons.location_city),
            title: Text(l10n.city),
            subtitle: Text(city?.name ?? cityId),
            trailing: TextButton(onPressed: () => context.go('/cities'), child: Text(l10n.changeCity)),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            trailing: DropdownButton<String>(
              value: s.locale?.languageCode ?? 'system',
              underline: const SizedBox.shrink(),
              items: [
                DropdownMenuItem(value: 'system', child: Text(l10n.themeSystem)),
                const DropdownMenuItem(value: 'es', child: Text('Español')),
                const DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (v) => n.setLocale(v == null || v == 'system' ? null : Locale(v)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.brightness_6_outlined),
                const SizedBox(width: 16),
                Text(l10n.theme),
                const Spacer(),
                SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: [
                    ButtonSegment(value: ThemeMode.system, label: Text(l10n.themeSystem)),
                    ButtonSegment(value: ThemeMode.light, icon: const Icon(Icons.light_mode, size: 16)),
                    ButtonSegment(value: ThemeMode.dark, icon: const Icon(Icons.dark_mode, size: 16)),
                  ],
                  selected: {s.themeMode},
                  onSelectionChanged: (v) => n.setThemeMode(v.first),
                ),
              ],
            ),
          ),
          SectionTitle(l10n.accessibility),
          SwitchListTile(
            secondary: const Icon(Icons.accessible),
            title: Text(l10n.wheelchairPref),
            value: s.wheelchair,
            onChanged: n.setWheelchair,
          ),
          ListTile(
            leading: const Icon(Icons.directions_walk),
            title: Text(l10n.walkingDistance),
            subtitle: Slider(
              value: s.maxWalkDistance.toDouble(),
              min: 300,
              max: 3000,
              divisions: 9,
              label: '${s.maxWalkDistance} m',
              onChanged: (v) => n.setMaxWalkDistance(v.round()),
            ),
            trailing: Text('${s.maxWalkDistance} m'),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.directions_bus),
            title: Text(l10n.liveVehicles),
            value: s.liveVehicles,
            onChanged: n.setLiveVehicles,
          ),
          SectionTitle(l10n.about),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text('${l10n.appTitle} ${AppConfig.appVersion}'),
            subtitle: Text(AppConfig.mock ? l10n.mockMode : AppConfig.apiUrl),
          ),
          if (city != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text('${l10n.dataSource}: ${city.attribution}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('MIT License · github.com/opentransit', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.outline)),
          ),
        ],
      ),
    );
  }
}
