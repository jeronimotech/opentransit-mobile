import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/providers.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/utils/format.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Download, inspect or delete a city's offline timetable.
///
/// The download is always an explicit tap and never happens on its own. That is the strongest
/// reading of "respect metered connections": rather than guess whether a connection is cheap, never
/// spend a rider's data without being asked, and put the size in the question. It also means the
/// app needs no connectivity plugin in order to be honest about this.
class OfflineTile extends ConsumerStatefulWidget {
  const OfflineTile({super.key, required this.cityId});
  final String cityId;

  @override
  ConsumerState<OfflineTile> createState() => _OfflineTileState();
}

class _OfflineTileState extends ConsumerState<OfflineTile> {
  double? _progress;
  CancelToken? _cancel;
  bool _failed = false;

  @override
  void dispose() {
    _cancel?.cancel();
    super.dispose();
  }

  Future<void> _download(OfflineBundleInfo info) async {
    final cancel = CancelToken();
    setState(() {
      _progress = 0;
      _failed = false;
      _cancel = cancel;
    });
    try {
      await ref.read(offlineStoreProvider).install(
            widget.cityId,
            url: info.url,
            expectedBytes: info.bytes,
            cancel: cancel,
            onProgress: (p) {
              if (mounted) setState(() => _progress = p);
            },
          );
      ref.invalidate(offlineMetaProvider(widget.cityId));
      ref.invalidate(offlineBundleProvider(widget.cityId));
    } on Object {
      // A cancel is not a failure, and showing "could not download" after the rider pressed stop
      // would blame the app for doing what it was told.
      if (mounted && !cancel.isCancelled) setState(() => _failed = true);
    } finally {
      if (mounted) {
        setState(() {
          _progress = null;
          _cancel = null;
        });
      }
    }
  }

  Future<void> _remove() async {
    await ref.read(offlineStoreProvider).remove(widget.cityId);
    ref.invalidate(offlineMetaProvider(widget.cityId));
    ref.invalidate(offlineBundleProvider(widget.cityId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final sem = context.semantic;
    final info = ref.watch(cityProvider(widget.cityId)).asData?.value.offline;
    final meta = ref.watch(offlineMetaProvider(widget.cityId)).asData?.value;
    final locale = Localizations.localeOf(context).toLanguageTag();

    // No bundle published for this city: say so plainly rather than offering a button that fails.
    if (info == null) {
      return ListTile(
        key: const ValueKey('settings-offline-unavailable'),
        leading: const Icon(Icons.cloud_off_outlined),
        title: Text(l10n.offlineTitle),
        subtitle: Text(l10n.offlineNotAvailable, style: TextStyle(color: scheme.onSurfaceVariant)),
        enabled: false,
      );
    }

    final progress = _progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          key: const ValueKey('settings-offline'),
          leading: Icon(meta == null ? Icons.download_outlined : Icons.offline_pin_outlined,
              color: meta == null ? null : sem.live),
          title: Text(l10n.offlineTitle),
          subtitle: Text(
            progress != null
                ? l10n.offlineDownloading
                : meta == null
                    ? l10n.offlineExplain
                    : '${l10n.offlineInstalled(formatDateShort(meta.installedAt, locale))} · '
                        '${l10n.offlineSize(formatBytes(meta.bytes))}',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          trailing: progress != null
              ? IconButton(
                  key: const ValueKey('offline-cancel'),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: MaterialLocalizations.of(context).cancelButtonLabel,
                  onPressed: () => _cancel?.cancel(),
                )
              : meta == null
                  // The size goes on the button, because it is the question being asked.
                  ? TextButton(
                      key: const ValueKey('offline-download'),
                      onPressed: () => _download(info),
                      child: Text('${l10n.offlineDownload} · ${formatBytes(info.bytes)}'),
                    )
                  : TextButton(
                      key: const ValueKey('offline-remove'),
                      onPressed: _remove,
                      child: Text(l10n.offlineRemove),
                    ),
        ),
        if (progress != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            // A download that has not reported yet is indeterminate rather than a bar stuck at 0.
            child: LinearProgressIndicator(value: progress == 0 ? null : progress),
          ),
        if (_failed)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(l10n.offlineFailed,
                style: TextStyle(fontSize: 11, color: sem.disruption)),
          ),
      ],
    );
  }
}
