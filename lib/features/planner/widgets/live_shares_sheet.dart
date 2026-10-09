import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers.dart';
import '../../../core/storage/live_shares.dart';
import '../../../core/utils/format.dart';
import '../../../l10n/generated/app_localizations.dart';

/// The live links this phone has published, and a button to take each one down.
///
/// Asked for by TransMilenio against 1.16.0 (1.10): the only "stop sharing" button lived inside the
/// trip that created the link, so closing the app left the page up until it expired on its own.
class LiveSharesSheet extends ConsumerStatefulWidget {
  const LiveSharesSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => const LiveSharesSheet(),
      );

  @override
  ConsumerState<LiveSharesSheet> createState() => _LiveSharesSheetState();
}

class _LiveSharesSheetState extends ConsumerState<LiveSharesSheet> {
  final _busy = <String>{};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final scheme = Theme.of(context).colorScheme;
    final repo = ref.watch(liveSharesProvider);
    final shares = repo.all();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(l10n.liveLinks,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          if (shares.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Text(l10n.liveLinksEmpty,
                  key: const ValueKey('live-shares-empty'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            )
          else
            for (final s in shares)
              ListTile(
                key: ValueKey('live-share-${s.token}'),
                leading: const Icon(Icons.share_location_rounded),
                title: Text(s.label ?? s.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                // The expiry is the thing a rider wants to know and was never shown: a link they
                // forgot about is only a problem if they cannot tell when it dies.
                subtitle: Text(s.expiresAt == null
                    ? l10n.liveLinkNoExpiry
                    : l10n.liveLinkExpiresAt(formatClock(s.expiresAt!, locale))),
                trailing: _busy.contains(s.token)
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: l10n.share,
                            icon: const Icon(Icons.ios_share_rounded, size: 20),
                            onPressed: () => SharePlus.instance.share(ShareParams(uri: Uri.parse(s.url))),
                          ),
                          TextButton(
                            key: ValueKey('live-share-stop-${s.token}'),
                            onPressed: () => _stop(s),
                            child: Text(l10n.stopSharing),
                          ),
                        ],
                      ),
              ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _stop(LiveShare s) async {
    setState(() => _busy.add(s.token));
    final api = ref.read(apiClientProvider);
    final repo = ref.read(liveSharesProvider);
    try {
      await api.revokeShare(s.cityId, s.token, s.writeKey);
    } on Object {
      // The page may already be gone — expired, or revoked from the trip that made it. Either way
      // the row has to go, or the rider is left with a button that never works.
    }
    await repo.remove(s.token);
    if (mounted) setState(() => _busy.remove(s.token));
  }
}
