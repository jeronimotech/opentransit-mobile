import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/utils/colors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/geo.dart';
import '../../core/utils/notifications.dart';
import '../../core/utils/polyline.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/transit_map.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/utils/ondemand.dart';
import '../ondemand/provider_picker.dart';
import 'planner_state.dart';

/// Pure logic behind "Iniciar viaje": which leg the user is on and how far
/// they are from the current leg's alighting point. Foreground location only.
class FollowAlongState {
  const FollowAlongState({required this.legIndex, required this.metersToLegEnd, required this.arrived});
  final int legIndex;
  final double metersToLegEnd;
  final bool arrived;
}

/// Picks the current leg: the first leg whose end the user has not reached
/// yet (within [reachMeters]) — legs are consumed in order, never skipped
/// backwards, so [previous] is a lower bound.
FollowAlongState followAlongStep(Itinerary it, LatLng here, {int previous = 0, double reachMeters = 60}) {
  var idx = previous.clamp(0, it.legs.length - 1);
  while (idx < it.legs.length - 1 && haversineMeters(here, it.legs[idx].to.position) <= reachMeters) {
    idx++;
  }
  final d = haversineMeters(here, it.legs[idx].to.position);
  final arrived = idx == it.legs.length - 1 && d <= reachMeters;
  return FollowAlongState(legIndex: idx, metersToLegEnd: d, arrived: arrived);
}

class FollowAlongScreen extends ConsumerStatefulWidget {
  const FollowAlongScreen({super.key, required this.cityId, required this.index});
  final String cityId;
  final int index;

  @override
  ConsumerState<FollowAlongScreen> createState() => _FollowAlongScreenState();
}

class _FollowAlongScreenState extends ConsumerState<FollowAlongScreen> {
  StreamSubscription<Position>? _sub;
  LatLng? _here;
  int _legIndex = 0;
  double? _toEnd;
  bool _arrived = false;
  bool _notified = false;
  bool _denied = false;
  static const _alertMeters = 300.0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await LocalNotifications.instance.requestPermission();
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _denied = true);
        return;
      }
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 10),
      ).listen(_onPosition, onError: (_) {});
    } catch (_) {
      if (mounted) setState(() => _denied = true);
    }
  }

  void _onPosition(Position p) {
    final it = _itinerary();
    if (it == null || !mounted) return;
    final here = LatLng(p.latitude, p.longitude);
    final st = followAlongStep(it, here, previous: _legIndex);
    final leg = it.legs[st.legIndex];
    if (st.legIndex != _legIndex) _notified = false;
    if ((leg.transit || leg.isRental) && !_notified && st.metersToLegEnd <= _alertMeters) {
      _notified = true;
      final l10n = AppLocalizations.of(context);
      if (leg.isRental) {
        // "Deja la bici en …": dock at the station the plan chose.
        LocalNotifications.instance.show(1, l10n.rentalDropoff(leg.rental?.dropoff?.name ?? leg.to.name), l10n.rentalDockHint);
      } else {
        LocalNotifications.instance.show(1, l10n.nextStopIsYours, l10n.getOffAt(leg.to.name));
      }
    }
    setState(() {
      _here = here;
      _legIndex = st.legIndex;
      _toEnd = st.metersToLegEnd;
      _arrived = st.arrived;
    });
  }

  Itinerary? _itinerary() {
    final plan = ref.read(plannerProvider).result?.asData?.value;
    if (plan == null || widget.index >= plan.itineraries.length) return null;
    return plan.itineraries[widget.index];
  }

  @override
  void dispose() {
    _sub?.cancel();
    LocalNotifications.instance.cancelAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final it = _itinerary();
    final city = ref.watch(currentCityProvider);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    if (it == null) {
      return Scaffold(appBar: AppBar(), body: EmptyView(icon: Icons.alt_route, message: l10n.noItineraries));
    }
    final leg = it.legs[_legIndex.clamp(0, it.legs.length - 1)];
    final lines = <MapLine>[];
    for (var i = 0; i < it.legs.length; i++) {
      final l = it.legs[i];
      final c = l.transit
          ? colorFromHex(l.route?.color, fallback: componentColor(l.route?.component, city: city))
          : l.isRental
              ? colorFromHex(l.rental!.color, fallback: const Color(0xFF00A859))
              : l.isOnDemand
                  ? colorFromHex(l.onDemand!.recommended?.color, fallback: const Color(0xFFF2C200))
                  : const Color(0xFF546E7A);
      final current = i == _legIndex;
      lines.add(MapLine(
        id: 'leg-$i',
        points: decodeGeometry(l.geometry),
        color: current ? c : c.withValues(alpha: 0.35),
        width: current ? 8 : 4,
        dashed: !l.transit && !l.isOnDemand,
      ));
    }
    final markers = [
      MapPoint(id: 'end', position: leg.to.position, color: scheme.primary, radius: 10, strokeWidth: 3, label: leg.to.name),
      if (_here != null) MapPoint(id: 'me', position: _here!, color: const Color(0xFF1E88E5), radius: 9, strokeWidth: 3),
    ];
    final legColor = leg.transit
        ? colorFromHex(leg.route?.color, fallback: componentColor(leg.route?.component, city: city))
        : leg.isRental
            ? colorFromHex(leg.rental!.color, fallback: const Color(0xFF00A859))
            : leg.isOnDemand
                ? colorFromHex(leg.onDemand!.recommended?.color, fallback: const Color(0xFFF2C200))
                : scheme.outline;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: TransitMap(
              initialCenter: _here ?? leg.from.position,
              initialZoom: 14,
              lines: lines,
              markers: markers,
              myLocation: !_denied,
              fitTo: _here == null ? decodeGeometry(leg.geometry) : [_here!, leg.to.position],
              fitPadding: const EdgeInsets.fromLTRB(40, 120, 40, 300),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 8,
            child: Material(
              color: scheme.surface,
              shape: const CircleBorder(),
              elevation: 4,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.pop(),
                child: const SizedBox(width: 44, height: 44, child: Icon(Icons.arrow_back)),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.paddingOf(context).bottom + 16),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(l10n.progressLabel(_legIndex + 1, it.legs.length),
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
                      const Spacer(),
                      Text(formatClock(it.endTime, locale), style: Theme.of(context).textTheme.labelLarge),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _arrived ? 1 : (_legIndex + (leg.distanceMeters > 0 && _toEnd != null ? (1 - (_toEnd! / leg.distanceMeters)).clamp(0, 1) : 0)) / it.legs.length,
                      minHeight: 6,
                      color: legColor,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_arrived)
                    Text(l10n.arrived, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))
                  else ...[
                    Row(
                      children: [
                        if (leg.transit)
                          RouteChip(leg.route)
                        else if (leg.isRental)
                          RentalChip(name: leg.rental!.networkName, color: legColor, electric: leg.rental!.isElectric)
                        else if (leg.isOnDemand)
                          OnDemandChip(
                              name: (city?.mobility.provider(leg.onDemand!.recommended?.providerId)?.kind ?? leg.onDemand!.displayKind) == 'taxi'
                                  ? l10n.onDemandTaxi
                                  : l10n.onDemandRidehail,
                              color: legColor,
                              taxi: (city?.mobility.provider(leg.onDemand!.recommended?.providerId)?.kind ?? leg.onDemand!.displayKind) == 'taxi')
                        else
                          RouteChip(null, mode: leg.mode),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            leg.transit
                                ? l10n.getOffAt(leg.to.name)
                                : leg.isRental
                                    ? l10n.rentalDropoff(leg.rental?.dropoff?.name ?? leg.to.name)
                                    : leg.isOnDemand
                                        ? l10n.requestVehicleTo(leg.to.name)
                                        : l10n.walkTo(leg.to.name),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _denied
                          ? l10n.followAlongLocationNeeded
                          : (_toEnd == null ? l10n.followAlongHint : l10n.distanceToStop(formatDistance(_toEnd!.round()))),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _denied ? scheme.error : scheme.onSurfaceVariant),
                    ),
                    // "Pide tu vehículo": the provider picker inline (top 3).
                    if (leg.isOnDemand)
                      Builder(builder: (context) {
                        final s = ref.read(plannerProvider);
                        final named = legsWithEndpointNames(it, fromName: s.from?.name, toName: s.to?.name);
                        final l = named[_legIndex.clamp(0, named.length - 1)];
                        return ProviderPicker(
                          key: const ValueKey('follow-ondemand-picker'),
                          cityId: widget.cityId,
                          from: l.from,
                          to: l.to,
                          options: leg.onDemand!.providers,
                          recommendedId: leg.onDemand!.recommendedProviderId,
                          compact: true,
                          maxRows: 3,
                        );
                      }),
                  ],
                  const SizedBox(height: 14),
                  FilledButton.tonalIcon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text(l10n.stopTrip),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
