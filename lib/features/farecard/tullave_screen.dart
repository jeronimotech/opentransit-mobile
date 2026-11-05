import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/farecard/fare_card_reader.dart';
import '../../core/farecard/tullave.dart';
import '../../core/providers.dart';
import '../../core/utils/fare.dart';
import '../../l10n/generated/app_localizations.dart';

/// "Mi tullave": read the card's balance, number and last movements by NFC, on-device.
class TullaveScreen extends ConsumerStatefulWidget {
  const TullaveScreen({super.key, required this.cityId});
  final String cityId;
  @override
  ConsumerState<TullaveScreen> createState() => _TullaveScreenState();
}

class _TullaveScreenState extends ConsumerState<TullaveScreen> {
  bool _scanning = false;
  TullaveCard? _card;
  FareCardReadError? _error;
  CardNfcState? _nfc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final s = await ref.read(fareCardReaderProvider).state();
      if (mounted) setState(() => _nfc = s);
    });
  }

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() { _scanning = true; _error = null; });
    try {
      final card = await ref.read(fareCardReaderProvider).readTullave();
      if (mounted) setState(() => _card = card);
    } on FareCardException catch (e) {
      if (mounted) setState(() => _error = e.reason);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final scheme = Theme.of(context).colorScheme;
    final unsupported = _nfc == CardNfcState.unsupported;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tullaveTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (_card != null) _balanceCard(context, l10n, locale, _card!),
          if (_card == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.contactless_rounded, size: 72, color: scheme.primary),
                  const SizedBox(height: 16),
                  Text(l10n.tullaveHold, textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _ErrorBanner(text: _errorText(l10n, _error!)),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: (_scanning || unsupported) ? null : _scan,
            icon: _scanning
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.contactless_outlined),
            label: Text(_scanning
                ? l10n.tullaveScanning
                : _card == null ? l10n.tullaveScan : l10n.tullaveRescan),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(
              children: [
                Icon(Icons.lock_outline, size: 15, color: scheme.outline),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(l10n.tullaveLocalRead,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.outline)),
                ),
              ],
            ),
          ),
          if (_card != null) ...[
            const SizedBox(height: 20),
            Text(l10n.tullaveMovements,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            if (_card!.movements.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(l10n.tullaveEmptyMovements,
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            for (final m in _card!.movements) _MovementRow(m: m, locale: locale),
          ],
        ],
      ),
    );
  }

  Widget _balanceCard(BuildContext context, AppLocalizations l10n, String locale, TullaveCard c) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.tullaveBalance.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: scheme.onPrimaryContainer, letterSpacing: 0.6)),
          const SizedBox(height: 4),
          Text(formatMoney(c.balanceCop, 'COP', locale),
              style: Theme.of(context).textTheme.displaySmall
                  ?.copyWith(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w800)),
          if (c.number.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('${l10n.tullaveNumber}  ${_grouped(c.number)}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onPrimaryContainer, fontFeatures: const [], letterSpacing: 1)),
          ],
        ],
      ),
    );
  }

  static String _grouped(String n) {
    final b = StringBuffer();
    for (var i = 0; i < n.length; i++) {
      if (i > 0 && i % 4 == 0) b.write(' ');
      b.write(n[i]);
    }
    return b.toString();
  }

  String _errorText(AppLocalizations l10n, FareCardReadError e) => switch (e) {
        FareCardReadError.unavailable => l10n.tullaveErrUnavailable,
        FareCardReadError.disabled => l10n.tullaveErrDisabled,
        FareCardReadError.timeout => l10n.tullaveErrTimeout,
        FareCardReadError.notTullave => l10n.tullaveErrNotTullave,
        FareCardReadError.failed => l10n.tullaveErrFailed,
      };
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.m, required this.locale});
  final TullaveMovement m;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final credit = m.kind == TullaveMovementKind.topUp;
    final label = switch (m.kind) {
      TullaveMovementKind.trip => l10n.tullaveTrip,
      TullaveMovementKind.topUp => l10n.tullaveTopUp,
      TullaveMovementKind.topUpReversal => l10n.tullaveTopUpReversal,
      TullaveMovementKind.unknown => l10n.tullaveMovementOther,
    };
    final icon = switch (m.kind) {
      TullaveMovementKind.trip => Icons.directions_bus_rounded,
      TullaveMovementKind.topUp => Icons.add_card_rounded,
      TullaveMovementKind.topUpReversal => Icons.undo_rounded,
      TullaveMovementKind.unknown => Icons.receipt_long_rounded,
    };
    final sign = credit ? '+' : '−';
    final amountColor = credit ? Colors.green.shade700 : scheme.onSurface;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: scheme.onSurfaceVariant),
      title: Text(label),
      subtitle: m.at == null
          ? null
          : Text(DateFormat.yMMMd(locale).add_Hm().format(m.at!.toLocal()),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.outline)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('$sign${formatMoney(m.amountCop, 'COP', locale)}',
              style: TextStyle(fontWeight: FontWeight.w700, color: amountColor)),
          Text(formatMoney(m.balanceAfterCop, 'COP', locale),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.outline)),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: scheme.onErrorContainer))),
        ],
      ),
    );
  }
}
