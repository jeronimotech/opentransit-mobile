import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Invisible widget that records one analytics event when it is first
/// mounted (and again only if its [id] changes). Lets screens report
/// `stop_view`, `route_view`, `locate_query`… without becoming stateful.
class TrackView extends ConsumerStatefulWidget {
  const TrackView({super.key, required this.type, required this.props, this.id});
  final String type;
  final Map<String, Object?> props;

  /// Identity of what is being viewed; a change re-fires the event.
  final String? id;

  @override
  ConsumerState<TrackView> createState() => _TrackViewState();
}

class _TrackViewState extends ConsumerState<TrackView> {
  String? _fired;

  void _fire() {
    final id = widget.id ?? widget.type;
    if (_fired == id) return;
    _fired = id;
    ref.read(analyticsProvider).track(widget.type, widget.props);
  }

  @override
  void initState() {
    super.initState();
    _fire();
  }

  @override
  void didUpdateWidget(TrackView old) {
    super.didUpdateWidget(old);
    _fire();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
