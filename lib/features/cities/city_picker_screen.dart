import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/utils/colors.dart';
import '../../core/utils/location.dart';
import '../../core/widgets/common.dart';
import '../../l10n/generated/app_localizations.dart';
import '../planner/planner_state.dart';
import 'city_for_position.dart';

class CityPickerScreen extends ConsumerStatefulWidget {
  const CityPickerScreen({super.key});

  @override
  ConsumerState<CityPickerScreen> createState() => _CityPickerScreenState();
}

class _CityPickerScreenState extends ConsumerState<CityPickerScreen> {
  bool _detecting = false;
  String? _detectNote;
  bool _autoTried = false;

  Future<void> _choose(BuildContext context, WidgetRef ref, City c) async {
    await ref.read(settingsProvider.notifier).setCity(c.id);
    ref.read(plannerProvider.notifier).reset();
    if (context.mounted) context.go('/${c.id}');
  }

  /// Pick the city the device is standing in.
  ///
  /// [ask] is false on the automatic pass: arriving at a fresh install with a system
  /// permission dialog before anything has been shown is not a welcome. When the
  /// permission is already there, this just works and nobody is asked anything.
  Future<void> _detect(List<City> list, {required bool ask}) async {
    if (_detecting) return;
    setState(() {
      _detecting = true;
      _detectNote = null;
    });
    final l10n = AppLocalizations.of(context);
    LatLng? at;
    try {
      at = ask ? await currentPosition() : await grantedPosition();
    } catch (_) {
      at = null;
    }
    if (!mounted) return;
    final found = at == null ? null : cityForPosition(list, at);
    if (found != null) {
      await _choose(context, ref, found);
      return;
    }
    if (!mounted) return;
    setState(() {
      _detecting = false;
      // Only say something when the person asked. A silent automatic attempt that
      // found nothing should leave the list exactly as it was.
      _detectNote = ask ? (at == null ? l10n.cityDetectFailed : l10n.cityNotCovered) : null;
    });
  }

  @override
  Widget build(BuildContext context) {
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
                  const SizedBox(height: 14),
                  cities.maybeWhen(
                    data: (list) => Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        key: const ValueKey('city-detect'),
                        onPressed: _detecting ? null : () => _detect(list, ask: true),
                        icon: _detecting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.my_location, size: 18),
                        label: Text(_detecting ? l10n.detectingCity : l10n.detectCity),
                      ),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  if (_detectNote != null) ...[
                    const SizedBox(height: 8),
                    Text(_detectNote!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
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
                data: (list) {
                  // One silent attempt per visit, and only where a choice has not
                  // already been made — nothing here overrides a person's decision.
                  if (!_autoTried && ref.read(settingsProvider).cityId == null) {
                    _autoTried = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _detect(list, ask: false);
                    });
                  }
                  return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _CityCard(
                    city: list[i],
                    onTap: () => _choose(context, ref, list[i]),
                  ),
                );
                },
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
