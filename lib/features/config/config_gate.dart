import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/providers.dart';
import '../../core/utils/version.dart';
import '../../l10n/generated/app_localizations.dart';

/// Blocks the app behind a maintenance or forced-update screen when the
/// selected city's remote config says so. Everything else passes through.
class ConfigGate extends ConsumerWidget {
  const ConfigGate({super.key, required this.child});
  final Widget child;

  static String? minVersionFor(CityConfigLike c) {
    if (kIsWeb) return null;
    if (Platform.isIOS) return c.minAppVersionIos;
    if (Platform.isAndroid) return c.minAppVersionAndroid;
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city = ref.watch(currentCityProvider);
    if (city == null) return child;
    final cfg = city.config;
    if (cfg.maintenance.active) {
      return _Blocker(
        icon: Icons.build_circle_outlined,
        title: AppLocalizations.of(context).maintenanceTitle,
        body: cfg.maintenance.message ?? AppLocalizations.of(context).maintenanceBody,
        action: AppLocalizations.of(context).checkAgain,
        onAction: () {
          ref.invalidate(citiesProvider);
          ref.invalidate(cityProvider(city.id));
        },
      );
    }
    final min = minVersionFor(CityConfigLike(cfg.minAppVersionIos, cfg.minAppVersionAndroid));
    if (needsUpdate(AppConfig.appVersion, min)) {
      final l10n = AppLocalizations.of(context);
      return _Blocker(
        key: const ValueKey('forced-update'),
        icon: Icons.system_update_alt_rounded,
        title: l10n.updateRequired,
        body: l10n.updateRequiredBody,
        action: l10n.updateAction,
        onAction: () async {
          final url = city.links.support;
          if (url == null) return;
          try {
            await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          } catch (_) {}
        },
      );
    }
    return child;
  }
}

/// Tiny value holder so [ConfigGate.minVersionFor] is testable without dart:io.
class CityConfigLike {
  const CityConfigLike(this.minAppVersionIos, this.minAppVersionAndroid);
  final String? minAppVersionIos;
  final String? minAppVersionAndroid;
}

class _Blocker extends StatelessWidget {
  const _Blocker({super.key, required this.icon, required this.title, required this.body, required this.action, required this.onAction});
  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(28)),
                  child: Icon(icon, size: 48, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(height: 24),
                Text(title, textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Text(body, textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 28),
                FilledButton(onPressed: onAction, child: Text(action)),
                const SizedBox(height: 12),
                Text('v${AppConfig.appVersion}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.outline)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
