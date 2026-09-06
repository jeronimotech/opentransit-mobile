import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../connectivity.dart';
import '../providers.dart';
import '../theme/semantic_colors.dart';

/// Slim status bar under the system status area (Lote 1 §4): red while the
/// API is unreachable, a short green flash when it comes back, amber when
/// live data is stale. Hidden otherwise, so it costs no space in normal use.
class ConnectivityBar extends ConsumerStatefulWidget {
  const ConnectivityBar({super.key, required this.child});

  /// The app below the bar; its status-bar inset is removed while the bar
  /// is showing, because the bar already covers that area.
  final Widget child;

  @override
  ConsumerState<ConnectivityBar> createState() => _ConnectivityBarState();
}

class _ConnectivityBarState extends ConsumerState<ConnectivityBar> {
  Timer? _flash;

  @override
  void dispose() {
    _flash?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final conn = ref.watch(connectionProvider);
    final cityId = ref.watch(settingsProvider).cityId;
    final health = cityId == null
        ? null
        : ref.watch(healthProvider(cityId)).asData?.value;
    final sem = context.semantic;

    Color? color;
    IconData icon = Icons.cloud_off_rounded;
    String? text;
    Key? key;
    if (!conn.online) {
      color = sem.severe;
      text = l10n.offlineBar;
      key = const ValueKey('bar-offline');
    } else if (conn.recoveredAt != null) {
      color = sem.live;
      icon = Icons.cloud_done_rounded;
      text = l10n.backOnlineBar;
      key = const ValueKey('bar-online');
      _flash ??= Timer(const Duration(seconds: 3), () {
        _flash = null;
        if (mounted) {
          ref.read(connectionProvider.notifier).acknowledgeRecovery();
        }
      });
    } else if (health != null &&
        health.realtime.enabled &&
        health.realtime.isStale) {
      color = sem.disruption;
      icon = Icons.history_toggle_off_rounded;
      final age = health.realtime.ageSeconds;
      text = age == null
          ? l10n.freshNoRealtime
          : l10n.staleBar(age.clamp(0, 99999));
      key = const ValueKey('bar-stale');
    }

    // Sits above the app: fill the status-bar inset in the same colour so the
    // text lands below the clock, and give the Text a Material ancestor.
    final topInset = MediaQuery.paddingOf(context).top;
    final bar = AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: text == null
          ? const SizedBox(width: double.infinity, height: 0)
          : Semantics(
              liveRegion: true,
              label: text,
              child: Material(
                key: key,
                color: color,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12, topInset + 5, 12, 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
    return Column(
      children: [
        bar,
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: text != null,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
