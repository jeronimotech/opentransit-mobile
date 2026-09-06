import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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
          SwitchListTile(
            secondary: const Icon(Icons.local_convenience_store_outlined),
            title: Text(l10n.poiLayer),
            value: s.poiLayer,
            onChanged: n.setPoiLayer,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.timeline_rounded),
            title: Text(l10n.layerNetwork),
            value: s.networkLayer,
            onChanged: n.setNetworkLayer,
          ),
          if (city != null && (city.links.pqrs != null || city.links.recharge != null || city.links.support != null)) ...[
            SectionTitle(l10n.services),
            if (city.links.recharge != null)
              ListTile(leading: const Icon(Icons.credit_card), title: Text(l10n.rechargeCard), trailing: const Icon(Icons.open_in_new, size: 18), onTap: () => _open(city.links.recharge!)),
            if (city.links.pqrs != null)
              ListTile(leading: const Icon(Icons.report_outlined), title: Text(l10n.pqrs), trailing: const Icon(Icons.open_in_new, size: 18), onTap: () => _open(city.links.pqrs!)),
            if (city.links.support != null)
              ListTile(leading: const Icon(Icons.support_agent), title: Text(l10n.about), trailing: const Icon(Icons.open_in_new, size: 18), onTap: () => _open(city.links.support!)),
          ],
          SectionTitle(l10n.privacyTitle),
          SwitchListTile(
            key: const ValueKey('analytics-toggle'),
            secondary: const Icon(Icons.insights_outlined),
            title: Text(l10n.analyticsToggle),
            subtitle: Text(l10n.analyticsExplain),
            value: ref.watch(analyticsEnabledProvider),
            onChanged: (v) => ref.read(analyticsEnabledProvider.notifier).set(v),
          ),
          ListTile(
            key: const ValueKey('analytics-clear'),
            leading: const Icon(Icons.delete_sweep_outlined),
            title: Text(l10n.analyticsClear),
            onTap: () async {
              await ref.read(analyticsProvider).clearData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.analyticsCleared)));
              }
            },
          ),
          if (city?.links.privacy != null)
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(l10n.privacyPolicy),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _open(city!.links.privacy!),
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
            child: Text('MIT License · github.com/jeronimotech/opentransit-mobile', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.outline)),
          ),
        ],
      ),
    );
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
