import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../l10n/generated/app_localizations.dart';

/// What this app does, for someone who just opened it — and for anyone who wants to look again.
///
/// Asked for by TransMilenio against 1.16.0 (1.7): there were hints scattered inside screens and
/// no single place that explains the app.
///
/// Deliberately not a welcome carousel. There is no account and nothing to set up, so a four-page
/// funnel would ask a rider to read instead of letting them travel. What was actually missing is a
/// page that can be read at any time, and a single dismissible pointer to it the first time. Each
/// entry answers one question a rider asks, and only the ones this city can answer are shown.
class GuideScreen extends ConsumerWidget {
  const GuideScreen({super.key, required this.cityId});

  final String cityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final city = ref.watch(cityProvider(cityId)).asData?.value;
    final scheme = Theme.of(context).colorScheme;

    final entries = <_Entry>[
      _Entry(Icons.alt_route_rounded, l10n.guidePlanTitle, l10n.guidePlanBody),
      if (city?.features.realtimeVehicles ?? false)
        _Entry(Icons.directions_bus_filled_rounded, l10n.guideLiveTitle, l10n.guideLiveBody),
      _Entry(Icons.navigation_rounded, l10n.guideGoTitle, l10n.guideGoBody),
      _Entry(Icons.cloud_download_outlined, l10n.guideOfflineTitle, l10n.guideOfflineBody),
      _Entry(Icons.accessible_rounded, l10n.guideAccessTitle, l10n.guideAccessBody),
      if (city?.features.fares ?? false)
        _Entry(Icons.payments_outlined, l10n.guideFareTitle, l10n.guideFareBody),
      _Entry(Icons.lock_outline_rounded, l10n.guidePrivacyTitle, l10n.guidePrivacyBody),
      _Entry(Icons.feedback_outlined, l10n.guideReportTitle, l10n.guideReportBody),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.guideTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(l10n.guideIntro(city?.name ?? ''),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(e.icon, color: scheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.title,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(e.body,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('guide-to-help'),
              onPressed: () => context.push('/$cityId/help'),
              icon: const Icon(Icons.support_agent, size: 18),
              label: Text(l10n.helpAndReports),
            ),
          ),
        ],
      ),
    );
  }
}

class _Entry {
  const _Entry(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}
