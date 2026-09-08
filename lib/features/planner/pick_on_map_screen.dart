import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics_event.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/utils/location.dart';
import '../../core/widgets/transit_map.dart';
import '../../l10n/generated/app_localizations.dart';
import 'planner_actions.dart';
import 'planner_state.dart';

/// Full-screen "choose on map" picker (contract v2.1).
///
/// The map fills the screen with a fixed crosshair at its centre; the user pans
/// the map *under* the crosshair. Every time the camera settles the centre is
/// reverse geocoded (debounced) and the name appears in the confirm bar, so the
/// user sees what they are about to pick. A nameless point is still a valid
/// endpoint: the bar falls back to the coordinates and confirm stays enabled.
class PickOnMapScreen extends ConsumerStatefulWidget {
  const PickOnMapScreen({
    super.key,
    required this.cityId,
    required this.field,
    this.initial,
  });

  final String cityId;
  final PlaceField field;

  /// Where to open the camera; defaults to the current value of the field,
  /// then the user's position, then the city centre. Never a hardcoded city.
  final LatLng? initial;

  @override
  ConsumerState<PickOnMapScreen> createState() => _PickOnMapScreenState();
}

class _PickOnMapScreenState extends ConsumerState<PickOnMapScreen> {
  final _mapKey = GlobalKey<TransitMapState>();
  Timer? _debounce;
  int _seq = 0;

  LatLng? _center;
  String? _name;
  bool _resolving = false;
  bool _confirming = false;
  LatLng? _start;

  static const _debounceMs = 350;

  @override
  void initState() {
    super.initState();
    _start = widget.initial ?? placeOf(ref.read(plannerProvider), widget.field)?.position;
    if (_start == null) _locate();
  }

  Future<void> _locate() async {
    try {
      final p = await currentPosition();
      if (!mounted || _start != null) return;
      setState(() => _start = p);
      await _mapKey.currentState?.animateTo(p, zoom: 16);
    } catch (_) {
      // No fix: the map stays on the city centre, which is always available.
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onCameraIdle(LatLng center, double zoom) {
    setState(() {
      _center = center;
      _resolving = true;
      _name = null;
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: _debounceMs), () => _resolve(center));
  }

  Future<void> _resolve(LatLng p) async {
    final seq = ++_seq;
    try {
      final place = await ref.read(apiClientProvider).reverse(widget.cityId, p);
      if (!mounted || seq != _seq) return;
      final n = place.name.trim();
      setState(() {
        _name = n.isEmpty ? null : n;
        _resolving = false;
      });
    } catch (_) {
      // Reverse geocoding is a nicety, not a gate: fall back to coordinates.
      if (!mounted || seq != _seq) return;
      setState(() {
        _name = null;
        _resolving = false;
      });
    }
  }

  /// The place the confirm bar would produce right now. Falls back to the
  /// reverse-geocoded street, then to the coordinates.
  Place? _pending() {
    final c = _center;
    if (c == null) return null;
    return Place(name: _name ?? c.toString(), position: c);
  }

  Future<void> _confirm() async {
    final place = _pending();
    if (place == null || _confirming) return;
    setState(() => _confirming = true);
    // A pending debounce would otherwise overwrite the label after the pop.
    _debounce?.cancel();
    _seq++;
    final router = GoRouter.of(context);
    ref.read(analyticsProvider).track(Ev.searchSelect, {
      'resultType': 'map',
      'field': widget.field.wire,
      'lat': place.position.lat,
      'lon': place.position.lon,
      'named': _name != null,
    });
    final canPlan = assignPlace(ref, widget.field, place);
    router.pop(place);
    if (canPlan) await runPlan(ref, router, widget.cityId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final city = ref.watch(cityProvider(widget.cityId)).asData?.value;
    final scheme = Theme.of(context).colorScheme;
    final center = _start ?? city?.center;
    final pending = _pending();
    final confirmLabel = widget.field == PlaceField.from
        ? l10n.pickOnMapConfirmOrigin
        : l10n.pickOnMapConfirmDestination;

    if (center == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.chooseOnMap)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Map first: full-bleed, everything else floats over it.
          Positioned.fill(
            child: TransitMap(
              key: _mapKey,
              initialCenter: center,
              initialZoom: 16,
              myLocation: true,
              onCameraIdle: _onCameraIdle,
              attributionBottomInset: 96,
            ),
          ),
          // Fixed crosshair: it never moves, the map moves under it.
          IgnorePointer(
            child: Center(
              child: Padding(
                // Lifts the pin tip onto the exact camera centre.
                padding: const EdgeInsets.only(bottom: 34),
                child: Icon(
                  Icons.place,
                  key: const ValueKey('pick-crosshair'),
                  size: 44,
                  color: widget.field == PlaceField.from ? scheme.primary : scheme.error,
                  shadows: const [Shadow(color: Colors.black38, blurRadius: 6)],
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 8,
            child: _RoundButton(
              icon: Icons.arrow_back,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onTap: () => context.pop(),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 8,
            child: _RoundButton(
              icon: Icons.my_location,
              tooltip: l10n.myLocation,
              onTap: () async {
                try {
                  final p = await currentPosition();
                  await _mapKey.currentState?.animateTo(p, zoom: 16.5);
                } on LocationDenied {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(l10n.locationDenied)));
                } catch (_) {
                  // transient location failure: leave the camera alone
                }
              },
            ),
          ),
          // Confirm bar: shows what is under the crosshair right now.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          widget.field == PlaceField.from ? Icons.trip_origin : Icons.flag_outlined,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.field.label(l10n),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: scheme.onSurfaceVariant)),
                              Text(
                                key: const ValueKey('pick-name'),
                                _resolving && _name == null
                                    ? l10n.pickOnMapSearching
                                    : (pending?.name ?? l10n.pickOnMapHint),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        if (_resolving)
                          const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(l10n.pickOnMapHint,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      key: const ValueKey('pick-confirm'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      // A nameless point is a valid endpoint, so the only thing
                      // that disables confirm is not knowing where the map is.
                      onPressed: pending == null || _confirming ? null : _confirm,
                      icon: const Icon(Icons.check),
                      label: Text(confirmLabel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface,
        shape: const CircleBorder(),
        elevation: 2,
        child: IconButton(tooltip: tooltip, icon: Icon(icon), onPressed: onTap),
      );
}
