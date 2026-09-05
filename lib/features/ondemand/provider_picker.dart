import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/utils/colors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/geo.dart';
import '../../core/utils/ondemand.dart';
import '../../l10n/generated/app_localizations.dart';

/// Compact ride picker (v1.4.2):
///   • ONE primary full-width button for the recommended provider
///     ("Pedir Taxi · ≈ $ 11.300–13.900", or "Pedir con Uber" without an estimate);
///   • one wrap-free row "O pide con:" + small pills for the other providers
///     (name only, provider colour, spinner inside while requesting);
///   • "Ver precios ▾" only when 2+ providers carry an estimate → dense rows
///     (icon · name · price, whole row tappable).
/// Provider identity comes only from the options / city config. The hand-off
/// goes through [requestRide] (API JSON → provider URL → store/web fallback).
class ProviderPicker extends ConsumerStatefulWidget {
  const ProviderPicker({
    super.key,
    required this.cityId,
    required this.from,
    required this.to,
    required this.options,
    this.recommendedId,
    this.compact = false,
    this.maxRows,
    this.onRequest,
    this.launcher,
    this.canLaunch,
  });
  final String cityId;

  /// Pickup / drop-off of the ride leg (names are prefilled in the provider app).
  final Place from;
  final Place to;
  final List<OnDemandOption> options;
  final String? recommendedId;

  /// Tighter paddings (follow-along sheet).
  final bool compact;

  /// Caps the secondary pills (the primary button always shows).
  final int? maxRows;

  /// Called after a hand-off attempt with the option and what was opened
  /// (`link | fallback | none`). Mainly for tests and analytics.
  final void Function(OnDemandOption option, String opened)? onRequest;

  /// Overrides the URL launcher / launchability check (tests).
  final Future<bool> Function(Uri)? launcher;
  final Future<bool> Function(Uri)? canLaunch;

  @override
  ConsumerState<ProviderPicker> createState() => _ProviderPickerState();
}

class _ProviderPickerState extends ConsumerState<ProviderPicker> {
  String? _busyId;
  bool _pricesOpen = false;

  Future<void> _request(OnDemandOption o, OnDemandProvider? provider) async {
    if (_busyId != null) return;
    setState(() => _busyId = o.providerId);
    // Fetch the hand-off JSON, then open the provider's own URL — never the API's.
    final opened = await requestRide(
      api: ref.read(apiClientProvider),
      cityId: widget.cityId,
      providerId: o.providerId,
      from: widget.from,
      to: widget.to,
      provider: provider,
      launcher: widget.launcher,
      canLaunch: widget.canLaunch,
    );
    if (!mounted) return;
    setState(() => _busyId = null);
    widget.onRequest?.call(o, opened);
    if (opened == 'none') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).onDemandOpenFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final city = ref.watch(currentCityProvider);
    final rows = sortOptions(widget.options, recommendedId: widget.recommendedId, city: city);
    if (rows.isEmpty) {
      return Text(l10n.onDemandNoProviders, style: TextStyle(color: scheme.outline, fontSize: 13));
    }
    final primary = rows.first;
    var others = rows.skip(1).toList();
    if (widget.maxRows != null) others = others.take(widget.maxRows!).toList();
    final priced = rows.where((o) => o.price != null).toList();
    final gap = widget.compact ? 6.0 : 8.0;
    OnDemandProvider? cfg(OnDemandOption o) => city?.mobility.provider(o.providerId);
    Color colorOf(OnDemandOption o) => ensureContrast(colorFromHex(o.color, fallback: const Color(0xFF455A64)), Colors.white);

    final primaryColor = colorOf(primary);
    final primaryLabel = primary.price != null
        ? l10n.requestProviderPriced(primary.name, formatPriceRange(primary.price!, locale))
        : l10n.requestWithProvider(primary.name);

    return Column(
      key: const ValueKey('ondemand-picker'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Primary action: the recommended provider.
        FilledButton.icon(
          key: ValueKey('ondemand-request-${primary.providerId}'),
          style: FilledButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: onColor(primaryColor),
            minimumSize: Size.fromHeight(widget.compact ? 44 : 48),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          onPressed: _busyId != null ? null : () => _request(primary, cfg(primary)),
          icon: _busyId == primary.providerId
              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: onColor(primaryColor)))
              : Icon((cfg(primary)?.kind ?? primary.kind) == 'taxi' ? Icons.local_taxi_rounded : Icons.directions_car_rounded, size: 18),
          label: Text(primaryLabel, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        // 2. "O pide con:" + pills for the other providers (single row, scrolls).
        if (others.isNotEmpty) ...[
          SizedBox(height: gap),
          SizedBox(
            height: 36,
            child: Row(
              children: [
                Text(l10n.orRequestWith, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(width: 6),
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final o in others) ...[
                        _ProviderPill(
                          key: ValueKey('ondemand-request-${o.providerId}'),
                          option: o,
                          color: colorOf(o),
                          busy: _busyId == o.providerId,
                          enabled: _busyId == null,
                          onTap: () => _request(o, cfg(o)),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        // 3. "Ver precios ▾" only when at least two providers have an estimate.
        if (priced.length >= 2) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('ondemand-prices-toggle'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(44, 32), visualDensity: VisualDensity.compact),
              onPressed: () => setState(() => _pricesOpen = !_pricesOpen),
              icon: Icon(_pricesOpen ? Icons.expand_less : Icons.expand_more, size: 18),
              label: Text(_pricesOpen ? l10n.hidePrices : l10n.seePrices),
            ),
          ),
          if (_pricesOpen)
            for (final o in priced)
              InkWell(
                key: ValueKey('ondemand-price-row-${o.providerId}'),
                borderRadius: BorderRadius.circular(8),
                onTap: _busyId != null ? null : () => _request(o, cfg(o)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
                  child: Row(
                    children: [
                      Icon((cfg(o)?.kind ?? o.kind) == 'taxi' ? Icons.local_taxi_rounded : Icons.directions_car_rounded,
                          size: 16, color: colorOf(o)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(o.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium)),
                      if (_busyId == o.providerId)
                        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        Text(formatPriceRange(o.price!, locale),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
        ],
      ],
    );
  }
}

/// Small pill in the provider colour: name only, spinner while requesting.
class _ProviderPill extends StatelessWidget {
  const _ProviderPill({super.key, required this.option, required this.color, required this.busy, required this.enabled, required this.onTap});
  final OnDemandOption option;
  final Color color;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = onColor(color);
    return Material(
      color: enabled || busy ? color : color.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy) ...[
                SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: fg)),
                const SizedBox(width: 6),
              ],
              Text(option.name, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

/// One muted line: applied surcharges + "Estimación según … · el taxímetro manda".
class TariffFootnote extends StatelessWidget {
  const TariffFootnote({super.key, required this.tariff, this.price});
  final TaxiTariff? tariff;
  final OnDemandPrice? price;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = tariff;
    final applied = price?.surchargesApplied ?? const [];
    final labels = [
      for (final id in applied)
        t?.surcharge(id)?.label ?? price?.breakdown.where((b) => b.id == id).firstOrNull?.label ?? id,
    ];
    if (t == null && labels.isEmpty) return const SizedBox.shrink();
    final parts = <String>[
      ...labels,
      if (t != null) l10n.tariffSource(t.sourceLabel ?? t.name),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        parts.join(' · '),
        key: const ValueKey('ondemand-footnote'),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.outline),
      ),
    );
  }
}

/// "{duration} · {distance}" meta shown next to the kind chip.
String rideMeta(Leg leg, AppLocalizations l10n) =>
    '${formatDuration(leg.durationSeconds, l10n)} · ${formatDistance(leg.distanceMeters)}';

/// "{duration} · {distance} en carro" summary line for a CAR leg.
String rideSummary(Leg leg, AppLocalizations l10n) =>
    l10n.onDemandRideLine(formatDuration(leg.durationSeconds, l10n), formatDistance(leg.distanceMeters));
