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

  /// Where this platform gets the update.
  ///
  /// The city's own value wins, because the destination has to be changeable
  /// without a release: a build that is blocked cannot be handed new code. The
  /// fallback is the platform's store for our own bundle id, so a city that never
  /// configured one still sends people somewhere real instead of nowhere — which is
  /// what happened when this opened the transit operator's support page.
  static String? updateUrlFor(CityConfigLike c) {
    if (kIsWeb) return null;
    if (Platform.isIOS) {
      return _clean(c.updateUrlIos) ?? "https://apps.apple.com/app/id${AppConfig.appStoreId}";
    }
    if (Platform.isAndroid) {
      return _clean(c.updateUrlAndroid) ??
          "https://play.google.com/store/apps/details?id=${AppConfig.packageName}";
    }
    return null;
  }

  static String? _clean(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();

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
          final url = updateUrlFor(
              CityConfigLike(cfg.minAppVersionIos, cfg.minAppVersionAndroid, cfg.updateUrlIos, cfg.updateUrlAndroid));
          if (url == null) return;
          final messenger = ScaffoldMessenger.maybeOf(context);
          try {
            final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            if (ok) return;
          } catch (_) {
            // fall through to the message
          }
          // A dead button on a screen you cannot leave is the worst outcome here.
          messenger?.showSnackBar(SnackBar(content: Text(l10n.updateOpenFailed)));
        },
      );
    }
    return child;
  }
}

/// Tiny value holder so [ConfigGate.minVersionFor] is testable without dart:io.
class CityConfigLike {
  const CityConfigLike(this.minAppVersionIos, this.minAppVersionAndroid,
      [this.updateUrlIos, this.updateUrlAndroid]);
  final String? minAppVersionIos;
  final String? minAppVersionAndroid;
  final String? updateUrlIos;
  final String? updateUrlAndroid;
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
