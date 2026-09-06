import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the API is reachable, as observed by the HTTP client (Lote 1:
/// the slim red/green bar). `recoveredAt` lets the bar flash green briefly
/// after an outage.
class ConnectionStatus {
  const ConnectionStatus({this.online = true, this.offlineSince, this.recoveredAt});
  final bool online;
  final DateTime? offlineSince;
  final DateTime? recoveredAt;

  ConnectionStatus copyWith({bool? online, DateTime? offlineSince, DateTime? recoveredAt, bool clearRecovered = false}) =>
      ConnectionStatus(
        online: online ?? this.online,
        offlineSince: online == true ? null : (offlineSince ?? this.offlineSince),
        recoveredAt: clearRecovered ? null : (recoveredAt ?? this.recoveredAt),
      );
}

class ConnectionNotifier extends Notifier<ConnectionStatus> {
  @override
  ConnectionStatus build() => const ConnectionStatus();

  /// Called by the API client after every request: `ok` is false only for
  /// network-level failures (never for 4xx/5xx answers).
  void report(bool ok, {DateTime? now}) {
    final t = now ?? DateTime.now();
    if (ok) {
      if (!state.online) state = ConnectionStatus(online: true, recoveredAt: t);
    } else if (state.online) {
      state = ConnectionStatus(online: false, offlineSince: t);
    }
  }

  /// The green "back online" flash has been shown.
  void acknowledgeRecovery() {
    if (state.recoveredAt != null) state = state.copyWith(clearRecovered: true);
  }
}

final connectionProvider = NotifierProvider<ConnectionNotifier, ConnectionStatus>(ConnectionNotifier.new);
