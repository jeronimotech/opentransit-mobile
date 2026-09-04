import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/utils/colors.dart';
import '../../core/widgets/common.dart';
import '../../l10n/generated/app_localizations.dart';
import '../planner/planner_state.dart';

class CityPickerScreen extends ConsumerWidget {
  const CityPickerScreen({super.key});

  Future<void> _choose(BuildContext context, WidgetRef ref, City c) async {
    await ref.read(settingsProvider.notifier).setCity(c.id);
    ref.read(plannerProvider.notifier).reset();
    if (context.mounted) context.go('/${c.id}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cities = ref.watch(citiesProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.directions_transit, color: scheme.onPrimary),
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.appTitle,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(l10n.chooseCity,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8)),
                  const SizedBox(height: 8),
                  Text(l10n.chooseCitySubtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Expanded(
              child: cities.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(citiesProvider),
                ),
                data: (list) => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _CityCard(
                    city: list[i],
                    onTap: () => _choose(context, ref, list[i]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CityCard extends StatelessWidget {
  const _CityCard({required this.city, required this.onTap});
  final City city;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = colorFromHex(city.primaryColor);
    final modes = city.modes.where((m) => m != TravelMode.walk).toList();
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  city.name.characters.first.toUpperCase(),
                  style: TextStyle(
                    color: onColor(color),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(city.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final m in modes)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: Icon(modeIcon(m), size: 14),
                            label: Text(modeLabel(m, l10n)),
                            padding: EdgeInsets.zero,
                            labelPadding: const EdgeInsets.only(right: 6),
                          ),
                        if (city.features.realtimeVehicles)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: LiveBadge(),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
