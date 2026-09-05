import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/utils/colors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/geo.dart';
import '../../core/utils/ondemand.dart';
import '../../l10n/generated/app_localizations.dart';

/// Rows of taxi / ride-hailing options with a "Pedir" button each: colour,
/// name, price (or "Precio en la app"), wait time. Provider identity comes
/// only from the options / city config.
class ProviderPicker extends ConsumerWidget {
  const ProviderPicker({
    super.key,
    required this.options,
    this.recommendedId,
    this.compact = false,
    this.maxRows,
    this.onRequest,
    this.launcher,
  });
  final List<OnDemandOption> options;
  final String? recommendedId;

  /// Dense rows for the follow-along sheet.
  final bool compact;
  final int? maxRows;

  /// Called after a hand-off attempt with the option and what was opened
  /// (`link | fallback | none`). Mainly for tests and analytics.
  final void Function(OnDemandOption option, String opened)? onRequest;

  /// Overrides the URL launcher (tests).
  final Future<bool> Function(Uri)? launcher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final city = ref.watch(currentCityProvider);
    var rows = sortOptions(options, recommendedId: recommendedId, city: city);
    if (maxRows != null) rows = rows.take(maxRows!).toList();
    if (rows.isEmpty) {
      return Text(l10n.onDemandNoProviders, style: TextStyle(color: scheme.outline, fontSize: 13));
    }
    return Column(
      key: const ValueKey('ondemand-picker'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final o in rows)
          _ProviderRow(
            key: ValueKey('ondemand-provider-${o.providerId}'),
            option: o,
            provider: city?.mobility.provider(o.providerId),
            recommended: o.providerId == recommendedId && rows.length > 1,
            compact: compact,
            locale: locale,
            onRequest: onRequest,
            launcher: launcher,
          ),
      ],
    );
  }
}

class _ProviderRow extends StatefulWidget {
  const _ProviderRow({
    super.key,
    required this.option,
    required this.provider,
    required this.recommended,
    required this.compact,
    required this.locale,
    this.onRequest,
    this.launcher,
  });
  final OnDemandOption option;
  final OnDemandProvider? provider;
  final bool recommended;
  final bool compact;
  final String locale;
  final void Function(OnDemandOption option, String opened)? onRequest;
  final Future<bool> Function(Uri)? launcher;

  @override
  State<_ProviderRow> createState() => _ProviderRowState();
}

class _ProviderRowState extends State<_ProviderRow> {
  bool _busy = false;

  Future<void> _request() async {
    setState(() => _busy = true);
    final opened = await openHandoff(
      handoffUrl: widget.option.handoffUrl,
      fallback: widget.provider == null ? null : providerFallbackLink(widget.provider!),
      launcher: widget.launcher,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onRequest?.call(widget.option, opened);
    if (opened == 'none') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).onDemandOpenFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final o = widget.option;
    final color = colorFromHex(o.color, fallback: const Color(0xFF455A64));
    final price = o.price;
    final isTaxi = (o.kind ?? widget.provider?.kind) == 'taxi';
    final title = Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700);
    final sub = Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);

    return Container(
      margin: EdgeInsets.only(top: widget.compact ? 4 : 6),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: widget.compact ? 6 : 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.recommended ? color.withValues(alpha: 0.7) : scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: widget.compact ? 28 : 34,
            height: widget.compact ? 28 : 34,
            decoration: BoxDecoration(color: ensureContrast(color, Colors.white), borderRadius: BorderRadius.circular(9)),
            child: Icon(isTaxi ? Icons.local_taxi_rounded : Icons.directions_car_rounded,
                size: widget.compact ? 16 : 19, color: onColor(ensureContrast(color, Colors.white))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(o.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: title)),
                    if (widget.recommended) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                        child: Text(l10n.recommended, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: scheme.onSurface)),
                      ),
                    ],
                  ],
                ),
                Text(
                  price != null ? formatPriceRange(price, widget.locale) : l10n.priceInApp,
                  style: price != null
                      ? Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)
                      : sub,
                ),
                if (o.waitSeconds != null)
                  Text(l10n.waitMinutes(((o.waitSeconds ?? 0) / 60).ceil()), style: sub),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: ValueKey('ondemand-request-${o.providerId}'),
            style: FilledButton.styleFrom(
              backgroundColor: ensureContrast(color, Colors.white),
              foregroundColor: onColor(ensureContrast(color, Colors.white)),
              minimumSize: const Size(64, 40),
              visualDensity: widget.compact ? VisualDensity.compact : VisualDensity.standard,
            ),
            onPressed: _busy ? null : _request,
            child: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.requestRide),
          ),
        ],
      ),
    );
  }
}

/// "Estimación según Decreto 042 de 2026 · el taxímetro manda" + surcharge chips.
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
    final chips = [
      for (final id in applied)
        t?.surcharge(id)?.label ?? price?.breakdown.where((b) => b.id == id).firstOrNull?.label ?? id,
    ];
    if (t == null && chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chips.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final c in chips)
                  Container(
                    key: ValueKey('surcharge-$c'),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(8)),
                    child: Text(c, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.onTertiaryContainer)),
                  ),
              ],
            ),
          if (t != null) ...[
            const SizedBox(height: 4),
            Text(
              l10n.tariffSource(t.sourceLabel ?? t.name),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.outline),
            ),
          ],
        ],
      ),
    );
  }
}

/// "{duration} · {distance} en carro" summary line for a CAR leg.
String rideSummary(Leg leg, AppLocalizations l10n) =>
    l10n.onDemandRideLine(formatDuration(leg.durationSeconds, l10n), formatDistance(leg.distanceMeters));
