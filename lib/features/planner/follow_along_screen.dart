import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/analytics/analytics.dart';
import '../../core/analytics/analytics_event.dart';
import '../../core/utils/colors.dart';
import '../../core/utils/eta.dart';
import '../../core/utils/format.dart';
import '../../core/utils/geo.dart';
import '../../core/utils/location.dart';
import '../../core/live_activity/live_activity.dart';
import '../../core/watch/watch_sync.dart';
import '../../core/utils/go_trip.dart';
import '../../core/utils/notifications.dart';
import '../../core/utils/polyline.dart';
import '../../core/utils/share_session.dart';
import '../../core/theme/semantic_colors.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/transit_map.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/utils/ondemand.dart';
import '../ondemand/provider_picker.dart';
import 'planner_state.dart';
import 'widgets/trip_receipt_sheet.dart';

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

/// A transit leg has two phases the screen used to collapse into one. Waiting at the boarding stop,
/// where the only thing that matters is when the bus comes; and riding, where it is where to get
/// off. GPS at a kerb wanders tens of metres, so the two thresholds differ: you are only counted as
/// boarded once you are well clear of the stop, and only counted as waiting again if you come back
/// to it. Without that the card flips between "sube" and "bájate" while you stand still.
const boardingWaitMeters = 120.0;
const boardingRideMeters = 250.0;

bool boardedTransitLeg(Leg leg, LatLng? here, {required bool wasBoarded}) {
  if (!leg.transit) return true;
  if (here == null) return wasBoarded;
  final d = haversineMeters(here, leg.from.position);
  return wasBoarded ? d > boardingWaitMeters : d > boardingRideMeters;
}

/// Arrival time as it looks from where you are now.
///
/// `itinerary.endTime` is what the router predicted before you set off and never moves: a tester
/// 1 km from his stop at 7:30 was still being told 7:59, twenty-four minutes of a bus that had
/// already made up the time. The current leg is re-estimated from the distance still to cover at
/// that leg's own average speed — the same arithmetic the lock screen already used for "minutes to
/// your stop" — and the legs after it keep their planned durations, which is the best we have for
/// a bus that has not come yet.
DateTime liveEta(Itinerary it, {required int legIndex, required double? metersToLegEnd, required DateTime now}) {
  final i = legIndex.clamp(0, it.legs.length - 1);
  final leg = it.legs[i];
  var seconds = 0.0;
  if (metersToLegEnd == null) {
    // No fix yet: the leg's planned duration is the honest answer.
    seconds += leg.durationSeconds.toDouble();
  } else if (leg.distanceMeters > 0 && leg.durationSeconds > 0) {
    seconds += metersToLegEnd / (leg.distanceMeters / leg.durationSeconds);
  }
  for (var j = i + 1; j < it.legs.length; j++) {
    seconds += it.legs[j].durationSeconds;
  }
  return now.add(Duration(seconds: seconds.round().clamp(0, 24 * 3600)));
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
  /// False while standing at the boarding stop of a transit leg; see [boardedTransitLeg].
  bool _boarded = false;
  bool _notified = false;
  bool _denied = false;
  static const _alertMeters = 300.0;

  DateTime? _goStartedAt;

  /// `ref` must not be touched once the element is unmounted, so everything
  /// `dispose` reports is captured while the widget is alive.
  Analytics? _analytics;
  Itinerary? _lastItinerary;

  final _offRoute = OffRouteDetector();
  bool _offRoutePrompt = false;
  bool _replanning = false;
  /// Whether the camera is still following; a pan sets this false.
  bool _following = true;
  /// Bumped to ask the map to resume following.
  int _recenter = 0;
  ShareSession? _share;
  LiveTrip? _liveTrip;
  bool _sharing = false;
  bool _shareBusy = false;

  @override
  void initState() {
    super.initState();
    _analytics = ref.read(analyticsProvider);
    final it = _itinerary();
    if (it != null) {
      _goStartedAt = DateTime.now();
      _analytics!.track(Ev.goStart, {'durationSeconds': it.durationSeconds, 'legs': it.legs.length, 'modes': it.modesUsed});
      _startCompanions(it);
    }
    _start();
  }

  Future<void> _start() async {
    await LocalNotifications.instance.requestPermission();
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied && !skipLocationPrompt) {
        // Explain before the system prompt: GO is the only place we ask.
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              key: const ValueKey('go-location-why'),
              icon: const Icon(Icons.my_location_rounded),
              content: Text(l10n.goLocationWhy),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(l10n.ok)),
              ],
            ),
          );
        }
        perm = await Geolocator.requestPermission();
      }
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
    if (st.legIndex != _legIndex) {
      _notified = false;
      _boarded = false;
      _offRoute.reset();
      _offRoutePrompt = false;
    }
    final boarded = boardedTransitLeg(leg, here, wasBoarded: _boarded);
    final l10n = AppLocalizations.of(context);
    if ((leg.transit || leg.isRental) && !_notified && st.metersToLegEnd <= _alertMeters) {
      _notified = true;
      // Haptics + sound: the phone is usually in a pocket at this moment.
      HapticFeedback.heavyImpact();
      if (leg.isRental) {
        // "Deja la bici en …": dock at the station the plan chose.
        LocalNotifications.instance.show(1, l10n.rentalDropoff(leg.rental?.dropoff?.name ?? leg.to.name), l10n.rentalDockHint);
      } else {
        LocalNotifications.instance.show(1, l10n.nextStopIsYours, l10n.getOffAt(leg.to.name));
      }
    }

    // Off route: sustained distance from the current leg's shape.
    final away = metersFromLeg(leg, here);
    final off = _offRoute.update(metersFromRoute: away, at: DateTime.now());
    if (off && !_offRoutePrompt) _offRoutePrompt = true;
    if (!off && _offRoutePrompt && away <= _offRoute.thresholdMeters) _offRoutePrompt = false;

    setState(() {
      _here = here;
      _legIndex = st.legIndex;
      _toEnd = st.metersToLegEnd;
      _arrived = st.arrived;
      _boarded = boarded;
    });
    _updateOngoing(it, leg);
    LiveActivity.instance.update(_liveUpdate(it, leg));
    _syncWatch(it, leg);
    if (_arrived) _onArrived(it);
  }

  /// Starts the Live Activity and the watch mirror. Both are best-effort:
  /// GO works exactly the same when neither is available.
  Future<void> _startCompanions(Itinerary it) async {
    final city = ref.read(cityProvider(widget.cityId)).asData?.value;
    final plan = ref.read(plannerProvider).result?.asData?.value;
    final origin = plan?.from.name ?? '';
    final destination = plan?.to.name ?? it.legs.last.to.name;
    _liveTrip = liveTripFor(
      cityId: widget.cityId,
      itinerary: it,
      originName: origin.isEmpty ? it.legs.first.from.name : origin,
      destinationName: destination,
      city: city,
    );
    await LiveActivity.instance.start(_liveTrip!, _liveUpdate(it, it.legs.first));
    await _syncWatch(it, it.legs.first);
  }

  DateTime _eta(Itinerary it) =>
      liveEta(it, legIndex: _legIndex, metersToLegEnd: _toEnd, now: DateTime.now());

  LiveTripUpdate _liveUpdate(Itinerary it, Leg leg) => LiveTripUpdate(
        etaAt: _eta(it),
        // Before the first fix there is no distance to work from; the leg's own
        // planned duration is the honest answer. Showing 0 would read as
        // "get off now" the moment the trip starts.
        minutesToNextStop:
            _toEnd == null ? (leg.durationSeconds / 60).round() : _minutesFor(leg, _toEnd!),
        nextStopName: leg.to.name,
        legIndex: _legIndex,
        totalLegs: it.legs.length,
        state: _arrived ? LiveTripState.arrived : LiveTripState.onTime,
      );

  /// Rough minutes left on this leg from the distance still to cover, using
  /// the leg's own average speed — the feed gives no per-position ETA.
  int _minutesFor(Leg leg, double metersLeft) {
    if (leg.durationSeconds <= 0 || leg.distanceMeters <= 0) return 0;
    final speed = leg.distanceMeters / leg.durationSeconds; // m/s
    if (speed <= 0) return 0;
    return (metersLeft / speed / 60).round().clamp(0, 999);
  }

  Future<void> _syncWatch(Itinerary it, Leg leg) async {
    final city = ref.read(cityProvider(widget.cityId)).asData?.value;
    await WatchSync.instance.sync(
      cityId: widget.cityId,
      cityName: city?.name ?? widget.cityId,
      apiBaseUrl: AppConfig.apiUrl,
      favourites: const [],
      go: WatchGoState(
        active: !_arrived,
        nextStopName: leg.to.name,
        minutesToNextStop: _toEnd == null ? null : _minutesFor(leg, _toEnd!),
        routeShortName: leg.route?.shortName,
        routeColor: _liveTrip?.routeColor,
        etaAt: _eta(it),
        alight: _notified && !_arrived,
      ),
    );
  }

  /// Keeps the persistent notification in step with the trip.
  void _updateOngoing(Itinerary it, Leg leg) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    LocalNotifications.instance.showOngoing(
      title: l10n.goNotificationTitle,
      body: l10n.goNotificationBody(
        leg.to.name,
        // Same number the Live Activity shows, from the same source, so the
        // watch, the lock screen and the app never disagree.
        _toEnd == null ? (leg.durationSeconds / 60).round() : _minutesFor(leg, _toEnd!),
        formatClock(_eta(it), locale),
      ),
      progress: _legIndex + 1,
      maxProgress: it.legs.length,
    );
  }

  bool _arrivalHandled = false;
  Future<void> _onArrived(Itinerary it) async {
    if (_arrivalHandled) return;
    _arrivalHandled = true;
    await _share?.finish(ShareState.arrived);
    await LocalNotifications.instance.cancelOngoing();
    await LiveActivity.instance.end();
    await _syncWatch(it, it.legs.last);
    if (!mounted) return;
    await TripReceiptSheet.show(
      context,
      buildReceipt(
        itinerary: it,
        actualSeconds: _goStartedAt == null ? it.durationSeconds : DateTime.now().difference(_goStartedAt!).inSeconds,
        completed: true,
      ),
    );
  }

  /// Current progress for the shared page, with coarse coordinates.
  ShareProgress _shareProgress() {
    final it = _itinerary();
    final here = _here;
    // Whoever is following the link sees the same arrival time as the traveller, not the one the
    // router guessed before the trip started.
    final eta = it == null ? null : _eta(it);
    return here == null
        ? ShareProgress(legIndex: _legIndex, etaAt: eta, state: _arrived ? ShareState.arrived : ShareState.onTime)
        : ShareProgress.at(
            legIndex: _legIndex,
            latitude: here.lat,
            longitude: here.lon,
            atStopId: it == null ? null : it.legs[_legIndex.clamp(0, it.legs.length - 1)].to.stopId,
            etaAt: eta,
            state: _arrived ? ShareState.arrived : ShareState.onTime,
          );
  }

  Future<void> _toggleShare() async {
    final it = _itinerary();
    if (it == null || _shareBusy) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _shareBusy = true);
    try {
      if (_sharing) {
        await _share?.revoke();
        if (!mounted) return;
        setState(() => _sharing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.shareTripStopped)));
        return;
      }
      final session = _share ??= ShareSession(ref.read(apiClientProvider), widget.cityId);
      final trip = await session.start(it, label: it.legs.last.to.name, progress: _shareProgress);
      if (!mounted) return;
      if (trip == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.shareTripFailed)));
        return;
      }
      setState(() => _sharing = true);
      await SharePlus.instance.share(ShareParams(uri: Uri.parse(trip.url)));
    } finally {
      if (mounted) setState(() => _shareBusy = false);
    }
  }

  /// Recalculate from where the person actually is, and keep following.
  ///
  /// This used to pop back to the itinerary screen, which threw someone mid-walk
  /// out of navigation and looked, reasonably, like nothing had been recalculated.
  /// A fresh plan is ordered best-first, so it continues on itinerary 0.
  Future<void> _replan() async {
    if (_replanning) return;
    final planner = ref.read(plannerProvider.notifier);
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    _offRoute.reset();
    setState(() {
      _offRoutePrompt = false;
      _replanning = true;
    });
    if (_here != null) {
      planner.setFrom(Place(name: l10n.myLocation, position: _here!));
    }
    final res = await planner.plan(widget.cityId);
    if (!mounted) return;
    setState(() => _replanning = false);
    if (res == null || res.itineraries.isEmpty) {
      // Stay in the trip that is still on screen: leaving someone with nothing
      // mid-journey is worse than an unchanged route.
      messenger.showSnackBar(SnackBar(content: Text(l10n.goReplanFailed)));
      return;
    }
    _lastItinerary = null;
    router.pushReplacement('/${widget.cityId}/itinerary/0/go');
  }

  Itinerary? _itinerary() {
    if (!mounted) return _lastItinerary;
    final plan = ref.read(plannerProvider).result?.asData?.value;
    if (plan == null || widget.index >= plan.itineraries.length) return _lastItinerary;
    return _lastItinerary = plan.itineraries[widget.index];
  }

  @override
  void dispose() {
    final it = _lastItinerary;
    if (it != null && _goStartedAt != null) {
      _analytics?.track(Ev.goEnd, {
        'durationSeconds': it.durationSeconds,
        'elapsedSeconds': DateTime.now().difference(_goStartedAt!).inSeconds,
        'completed': _arrived,
        'legs': it.legs.length,
      });
    }
    _sub?.cancel();
    _share?.dispose();
    LocalNotifications.instance.cancelAll();
    // Fire-and-forget: `dispose` cannot await, and a leftover activity on the
    // lock screen is worse than a redundant end call.
    LiveActivity.instance.end();
    super.dispose();
  }

  /// Stop button: finish the share, drop the notification and show what the
  /// trip cost even when it was abandoned.
  Future<void> _stop() async {
    final it = _itinerary();
    await _share?.finish(_arrived ? ShareState.arrived : ShareState.cancelled);
    await LocalNotifications.instance.cancelOngoing();
    await LiveActivity.instance.end();
    await WatchSync.instance.sync(
      cityId: widget.cityId,
      cityName: widget.cityId,
      apiBaseUrl: AppConfig.apiUrl,
      favourites: const [],
    );
    if (!mounted) return;
    if (it != null && !_arrivalHandled) {
      _arrivalHandled = true;
      await TripReceiptSheet.show(
        context,
        buildReceipt(
          itinerary: it,
          actualSeconds: _goStartedAt == null ? 0 : DateTime.now().difference(_goStartedAt!).inSeconds,
          completed: _arrived,
        ),
      );
    }
    if (mounted) context.pop();
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
              // Navigation camera: follows the device, turned so the way ahead is up.
              // It used to refit the bounds between you and the leg's end on every
              // fix, which is an overview of the walk, not a view for walking it.
              // Off once arrived: the overview is the useful view then.
              navigating: !_denied && !_arrived,
              recenterSignal: _recenter,
              onTrackingDismissed: () {
                if (mounted) setState(() => _following = false);
              },
              fitTo: _here == null ? decodeGeometry(leg.geometry) : [_here!, leg.to.position],
              fitPadding: const EdgeInsets.fromLTRB(40, 120, 40, 300),
            ),
          ),
          // Offered only when a gesture broke the follow, so it never sits there
          // competing with the map.
          if (!_following && !_denied && !_arrived)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              right: 8,
              child: Material(
                key: const ValueKey('go-recenter'),
                color: scheme.surface,
                borderRadius: BorderRadius.circular(22),
                elevation: 4,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => setState(() {
                    _following = true;
                    _recenter++;
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.navigation_rounded, size: 18, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(l10n.goRecenter,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
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
                      Text(formatClock(_eta(it), locale), style: Theme.of(context).textTheme.labelLarge),
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
                                ? (_boarded ? l10n.getOffAt(leg.to.name) : l10n.boardAt(leg.from.name))
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
                    // While waiting for the bus, "4.9 km to your stop" is the distance to where you
                    // get *off* — a number that reads as if the bus stop were 4.9 km away. What the
                    // rider needs there is the wait, so the arrivals take that line instead.
                    if (leg.transit && !_boarded && leg.route != null && leg.from.stopId != null)
                      WaitingForBus(
                        key: const ValueKey('go-waiting'),
                        cityId: widget.cityId,
                        stopId: leg.from.stopId!,
                        routeId: leg.route!.id,
                        getOff: leg.to.name,
                      )
                    else
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
                          maxRows: 4,
                        );
                      }),
                  ],
                  if (_offRoutePrompt && !_arrived) ...[
                    const SizedBox(height: 12),
                    Container(
                      key: const ValueKey('go-off-route'),
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                      decoration: BoxDecoration(
                        color: context.semantic.disruption.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.wrong_location_rounded, size: 18, color: context.semantic.disruption),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(l10n.goOffRoute,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                          ),
                          TextButton(
                            key: const ValueKey('go-dismiss'),
                            onPressed: () {
                              _offRoute.reset();
                              setState(() => _offRoutePrompt = false);
                            },
                            child: Text(l10n.goDismiss),
                          ),
                          FilledButton(
                            key: const ValueKey('go-replan'),
                            onPressed: _replan,
                            child: Text(l10n.goReplan),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          key: const ValueKey('go-stop'),
                          onPressed: _stop,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: Text(l10n.stopTrip),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        key: const ValueKey('go-share'),
                        onPressed: _shareBusy ? null : _toggleShare,
                        icon: _shareBusy
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(_sharing ? Icons.stop_screen_share_outlined : Icons.ios_share_rounded, size: 18),
                        label: Text(_sharing ? l10n.shareTripStop : l10n.shareTrip),
                      ),
                    ],
                  ),
                  if (_sharing)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: context.semantic.live),
                          const SizedBox(width: 6),
                          Text(l10n.shareTripActive,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.semantic.live)),
                        ],
                      ),
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

/// The wait at the boarding stop: when the leg's own route reaches this stop, live where the feed
/// says so. Falls back to naming the stop when the API has nothing, because "no data" is a better
/// answer than the distance to a stop you have not reached yet.
class WaitingForBus extends ConsumerWidget {
  const WaitingForBus({
    super.key,
    required this.cityId,
    required this.stopId,
    required this.routeId,
    required this.getOff,
  });
  final String cityId;
  final String stopId;
  final String routeId;

  /// Where this leg ends: kept in view so the destination is never lost while waiting.
  final String getOff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final data = ref.watch(nextBusesProvider(StopRouteKey(cityId, stopId, routeId))).asData?.value;
    final next = (data?.next ?? const <NextBus>[]).take(3).toList();
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (next.isEmpty)
          Text(data == null ? l10n.followAlongHint : l10n.noBuses, style: muted)
        else ...[
          Row(
            children: [
              Text(l10n.nextDeparturesHere,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              // Same three words the arrivals board uses, so "en vivo" means the same everywhere.
              Text(
                next.first.isLive
                    ? l10n.sourceLive
                    : (next.first.isEstimated ? l10n.sourceEstimated : l10n.sourceScheduled),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: next.first.isLive
                          ? context.semantic.live
                          : (next.first.isEstimated ? context.semantic.disruption : scheme.outline),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // Keyed by position: two buses of the same route can be predicted for the same
              // second, and duplicate keys crash the Wrap (seen against the live Bogotá feed).
              for (final (i, n) in next.indexed)
                Container(
                  key: ValueKey('go-eta-$i'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: etaColor(etaBucket(n.minutes)).withValues(alpha: i == 0 ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    n.minutes <= 0 ? l10n.arrivingNow : l10n.inMinutes(n.minutes),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w600),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 6),
        Text(l10n.getOffAt(getOff), style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
