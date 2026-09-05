import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/utils/colors.dart';
import '../../core/utils/text.dart';
import '../../core/utils/fare.dart';
import '../../core/utils/format.dart';
import '../../core/utils/links.dart';
import '../../core/utils/geo.dart';
import '../../core/utils/polyline.dart';
import '../../core/utils/rental.dart';
import '../ondemand/provider_picker.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/transit_map.dart';
import '../../l10n/generated/app_localizations.dart';
import 'planner_state.dart';

class ItineraryDetailScreen extends ConsumerStatefulWidget {
  const ItineraryDetailScreen({super.key, required this.cityId, required this.index});
  final String cityId;
  final int index;

  @override
  ConsumerState<ItineraryDetailScreen> createState() => _ItineraryDetailScreenState();
}

class _ItineraryDetailScreenState extends ConsumerState<ItineraryDetailScreen> {
  List<MapLine>? _lines;
  List<MapPoint>? _stops;
  List<MapPoint>? _markers;
  List<LatLng>? _fit;
  Itinerary? _built;

  void _buildOverlays(Itinerary it) {
    if (identical(_built, it)) return;
    _built = it;
    final lines = <MapLine>[];
    final stops = <MapPoint>[];
    final all = <LatLng>[];
    for (var i = 0; i < it.legs.length; i++) {
      final leg = it.legs[i];
      final pts = decodeGeometry(leg.geometry);
      all.addAll(pts);
      final rental = leg.rental;
      final onDemand = leg.onDemand;
      final color = leg.transit
          ? colorFromHex(leg.route?.color, fallback: componentColor(leg.route?.component, city: ref.read(currentCityProvider)))
          : rental != null
              ? colorFromHex(rental.color, fallback: const Color(0xFF00A859))
              : onDemand != null
                  ? colorFromHex(onDemand.recommended?.color, fallback: const Color(0xFFF2C200))
                  : const Color(0xFF546E7A);
      // Rental legs: dashed line in the network colour, docking stations as rings.
      // On-demand legs: solid line in the provider colour.
      lines.add(MapLine(id: 'leg-$i', points: pts, color: color, width: leg.transit ? 6 : (rental != null || onDemand != null ? 5 : 4), dashed: !leg.transit && onDemand == null));
      if (rental != null) {
        stops.add(MapPoint(id: 'rp-$i', position: leg.from.position, color: Colors.white, strokeColor: color, strokeWidth: 3.5, radius: 7, label: rental.pickup?.name ?? leg.from.name));
        stops.add(MapPoint(id: 'rd-$i', position: leg.to.position, color: Colors.white, strokeColor: color, strokeWidth: 3.5, radius: 7, label: rental.dropoff?.name ?? leg.to.name));
      }
      if (leg.transit) {
        stops.add(MapPoint(id: 'b-$i', position: leg.from.position, color: Colors.white, strokeColor: color, strokeWidth: 3, radius: 6, label: leg.from.name));
        stops.add(MapPoint(id: 'a-$i', position: leg.to.position, color: Colors.white, strokeColor: color, strokeWidth: 3, radius: 6, label: leg.to.name));
        for (final s in leg.intermediateStops) {
          stops.add(MapPoint(id: 'i-$i-${s.stopId}', position: s.position, color: Colors.white, strokeColor: color, strokeWidth: 2, radius: 3));
        }
      }
    }
    final first = it.legs.first.from.position;
    final last = it.legs.last.to.position;
    _lines = lines;
    _stops = stops;
    _markers = [
      MapPoint(id: 'origin', position: first, color: const Color(0xFF2E7D32), radius: 9, strokeWidth: 3),
      MapPoint(id: 'dest', position: last, color: const Color(0xFFC62828), radius: 9, strokeWidth: 3),
    ];
    _fit = all.isEmpty ? [first, last] : all;
  }

  /// Canonical https URL (App Link / Universal Link) shared via the OS sheet.
  Uri _shareLink(PlanRequest r) => CanonicalLinks.plan(widget.cityId, r);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(plannerProvider);
    final city = ref.watch(cityProvider(widget.cityId)).asData?.value;
    final fare = planFare(s, widget.index, city);
    final plan = s.result?.asData?.value;
    final it = plan != null && widget.index < plan.itineraries.length ? plan.itineraries[widget.index] : null;
    if (it == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.itinerary)),
        body: EmptyView(icon: Icons.alt_route, message: l10n.noItineraries),
      );
    }
    _buildOverlays(it);
    final named = _withNames(it, s.from?.name, s.to?.name);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: TransitMap(
              initialCenter: city?.center ?? it.legs.first.from.position,
              initialZoom: 12,
              lines: _lines!,
              stops: _stops!,
              markers: _markers!,
              fitTo: _fit,
              fitPadding: const EdgeInsets.fromLTRB(40, 120, 40, 360),
              onStopTap: (id) {
                final leg = it.legs.where((l) => l.transit).toList();
                for (final l in leg) {
                  for (final p in [l.from, l.to, ...l.intermediateStops]) {
                    if (p.stopId != null && id.endsWith(p.stopId!)) {
                      context.push('/${widget.cityId}/stops/${Uri.encodeComponent(p.stopId!)}');
                      return;
                    }
                  }
                }
              },
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 8,
            child: _CircleButton(icon: Icons.arrow_back, onTap: () => context.pop()),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 8,
            child: _CircleButton(
              icon: Icons.share_outlined,
              onTap: () async {
                final req = s.request;
                if (req == null) return;
                await SharePlus.instance.share(ShareParams(uri: _shareLink(req), subject: l10n.shareTrip));
              },
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.2,
            maxChildSize: 0.92,
            snap: true,
            snapSizes: const [0.2, 0.45, 0.92],
            builder: (context, controller) => Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16)],
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatDuration(it.durationSeconds, l10n),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('${formatClock(it.startTime, locale)} – ${formatClock(it.endTime, locale)}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                      ),
                      const Spacer(),
                      if (it.hasRealtime) const LiveBadge(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${l10n.transfersCount(it.transfers)} · ${l10n.walkDistance(it.walkDistanceMeters)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  _FareBlock(fare: fare),
                  const SizedBox(height: 10),
                  if (city?.config.isEnabled('followAlong') ?? true)
                    FilledButton.icon(
                      key: const ValueKey('start-trip'),
                      onPressed: () => context.push('/${widget.cityId}/itinerary/${widget.index}/go'),
                      icon: const Icon(Icons.navigation_rounded),
                      label: Text(l10n.startTrip),
                    ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < named.length; i++)
                    _LegTile(
                      cityId: widget.cityId,
                      leg: named[i],
                      isLast: i == named.length - 1,
                      network: city?.mobility.network(named[i].rental?.networkId),
                    ),
                  _EndTile(place: named.last.to, time: it.endTime),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Fare? planFare(PlannerState s, int index, City? city) {
  final plan = s.result?.asData?.value;
  if (plan == null || index >= plan.itineraries.length) return null;
  return fareFor(plan.itineraries[index], city);
}

/// "Tarifa estimada · $ 3.200" with the breakdown lines (Pasaje / Transbordo).
class _FareBlock extends StatelessWidget {
  const _FareBlock({required this.fare});
  final Fare? fare;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final f = fare;
    return Container(
      key: const ValueKey('fare-block'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(14)),
      child: f == null
          ? Row(children: [
              Icon(Icons.payments_outlined, size: 18, color: scheme.outline),
              const SizedBox(width: 8),
              Text(l10n.fareNotPublished, style: TextStyle(color: scheme.outline)),
            ])
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.payments_outlined, size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text(f.estimated ? l10n.estimatedFare : l10n.fareBase, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(f.amount == null ? (f.note ?? l10n.priceInApp) : formatMoney(f.amount!, f.currency, locale),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800, color: f.amount == null ? scheme.outline : null)),
                  ],
                ),
                if (f.breakdown.length > 1 || f.breakdown.any((l) => l.isRental || l.isOnDemand)) ...[
                  const SizedBox(height: 6),
                  for (final line in f.breakdown)
                    Padding(
                      padding: const EdgeInsets.only(left: 26, top: 2),
                      child: Row(children: [
                        Text(line.label == 'base' || line.label == 'Pasaje' ? l10n.fareBase : (line.label == 'transfer' || line.label == 'Transbordo' ? l10n.fareTransfer : line.label),
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                        const Spacer(),
                        Text(formatMoney(line.amount, f.currency, locale), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                      ]),
                    ),
                ],
                if (f.estimated) ...[
                  const SizedBox(height: 6),
                  Text(l10n.fareEstimatedNote, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.outline)),
                ],
              ],
            ),
    );
  }
}

/// OTP leaves origin/destination `Place.name` empty for raw coordinates; use
/// the names the user picked instead.
List<Leg> _withNames(Itinerary it, String? fromName, String? toName) {
  if (it.legs.isEmpty) return it.legs;
  Leg fix(Leg l, {bool first = false, bool last = false}) {
    final from = first && l.from.name.trim().isEmpty && fromName != null ? l.from.copyWith(name: fromName) : l.from;
    final to = last && l.to.name.trim().isEmpty && toName != null ? l.to.copyWith(name: toName) : l.to;
    if (identical(from, l.from) && identical(to, l.to)) return l;
    return l.copyWith(from: from, to: to);
  }
  return [
    for (var i = 0; i < it.legs.length; i++)
      fix(it.legs[i], first: i == 0, last: i == it.legs.length - 1),
  ];
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: Colors.black26,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 44, height: 44, child: Icon(icon)),
        ),
      );
}

class _LegTile extends StatefulWidget {
  const _LegTile({required this.cityId, required this.leg, required this.isLast, this.network});
  final String cityId;
  final Leg leg;
  final bool isLast;

  /// The configured network behind a rental leg (links, app), if any.
  final BikeShareNetwork? network;
  @override
  State<_LegTile> createState() => _LegTileState();
}

class _LegTileState extends State<_LegTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final scheme = Theme.of(context).colorScheme;
    final leg = widget.leg;
    final rental = leg.rental;
    final onDemand = leg.onDemand;
    final color = leg.transit
        ? colorFromHex(leg.route?.color, fallback: componentColor(leg.route?.component))
        : rental != null
            ? colorFromHex(rental.color, fallback: const Color(0xFF00A859))
            : onDemand != null
                ? colorFromHex(onDemand.recommended?.color, fallback: const Color(0xFFF2C200))
                : scheme.outline;
    final delay = formatDelay(leg.delaySeconds, l10n);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 48,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatClock(leg.startTime, locale), style: const TextStyle(fontWeight: FontWeight.w700)),
                if (leg.transit && leg.realtime)
                  Text(l10n.realtime, style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                width: 14, height: 14,
                decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.surface, border: Border.all(color: color, width: 3)),
              ),
              Expanded(
                child: leg.transit || onDemand != null
                    ? Container(width: 6, color: color)
                    : _DottedBar(color: color),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leg.transit) ...[
                    InkWell(
                      onTap: leg.from.stopId == null ? null : () => context.push('/${widget.cityId}/stops/${Uri.encodeComponent(leg.from.stopId!)}'),
                      child: Text(l10n.boardAt(leg.from.name), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        InkWell(
                          onTap: leg.route == null ? null : () => context.push('/${widget.cityId}/routes/${Uri.encodeComponent(leg.route!.id)}'),
                          child: RouteChip(leg.route),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            headsignLabel(leg.headsign, towards: l10n.towards) ?? cleanHeadsign(leg.route?.longName) ?? '',
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('${formatDuration(leg.durationSeconds, l10n)} · ${formatDistance(leg.distanceMeters)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                        if (delay != null) ...[
                          const SizedBox(width: 8),
                          Text(delay, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                              color: (leg.delaySeconds ?? 0) > 60 ? Colors.orange.shade800 : Colors.green.shade700)),
                        ],
                      ],
                    ),
                    if (leg.intermediateStops.isNotEmpty)
                      InkWell(
                        onTap: () => setState(() => _expanded = !_expanded),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18, color: color),
                              const SizedBox(width: 4),
                              Text(l10n.intermediateStops(leg.intermediateStops.length),
                                  style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    if (_expanded)
                      for (final s in leg.intermediateStops)
                        Padding(
                          padding: const EdgeInsets.only(left: 22, top: 2, bottom: 2),
                          child: Row(
                            children: [
                              Expanded(child: Text(s.name, style: Theme.of(context).textTheme.bodySmall)),
                              if (s.arrival != null)
                                Text(formatClock(s.arrival!, locale), style: Theme.of(context).textTheme.labelSmall),
                            ],
                          ),
                        ),
                    for (final a in leg.alerts)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            alertIcon(a.severity, size: 16),
                            const SizedBox(width: 6),
                            Expanded(child: Text(a.header, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(l10n.rideTo(leg.to.name), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  ] else if (rental != null) ...[
                    _RentalLegBody(leg: leg, rental: rental, network: widget.network, color: color),
                  ] else if (onDemand != null) ...[
                    _OnDemandLegBody(cityId: widget.cityId, leg: leg, onDemand: onDemand, color: color),
                  ] else ...[
                    Text(l10n.walkTo(leg.to.name), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${modeLabel(leg.mode, l10n)} · ${formatDuration(leg.durationSeconds, l10n)} · ${formatDistance(leg.distanceMeters)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    if (leg.steps.isNotEmpty)
                      InkWell(
                        onTap: () => setState(() => _expanded = !_expanded),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18, color: scheme.primary),
                              const SizedBox(width: 4),
                              Text(l10n.walkSteps, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    if (_expanded)
                      for (final st in leg.steps)
                        Padding(
                          padding: const EdgeInsets.only(left: 4, top: 3, bottom: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(_stepIcon(st.relativeDirection), size: 16, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 8),
                              Expanded(child: Text(st.instruction, style: Theme.of(context).textTheme.bodySmall)),
                              Text(formatDistance(st.distanceMeters), style: Theme.of(context).textTheme.labelSmall),
                            ],
                          ),
                        ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pickup card → ride line → drop-off card → price and app hand-off for a
/// shared-bike leg. Everything provider-specific comes from the network config.
class _RentalLegBody extends StatelessWidget {
  const _RentalLegBody({required this.leg, required this.rental, required this.network, required this.color});
  final Leg leg;
  final LegRental rental;
  final BikeShareNetwork? network;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final pickup = rental.pickup;
    final dropoff = rental.dropoff;
    final price = rental.priceEstimate;
    final appLink = network == null ? null : rentalAppLink(network!);
    final pickupAge = pickup?.ageSeconds();

    Widget stationCard({required String title, required RentalStation? st, required bool isPickup, required Key key}) {
      final count = isPickup ? st?.vehiclesAvailable : st?.docksAvailable;
      final ok = isPickup ? (st?.canRent ?? true) : (st?.canReturn ?? true);
      return Container(
        key: key,
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isPickup ? Icons.pedal_bike : Icons.local_parking_rounded, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
              ],
            ),
            if (st != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      isPickup ? l10n.bikesAvailable(count ?? 0) : l10n.docksAvailable(count ?? 0),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ok ? Colors.green.shade700 : Colors.orange.shade800),
                    ),
                    if (isPickup && (st.ebikesAvailable ?? 0) > 0)
                      Text(l10n.ebikesShort(st.ebikesAvailable!), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    if (!ok)
                      Text(isPickup ? l10n.rentalNotRenting : l10n.rentalNotReturning,
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            RentalChip(name: rental.networkName, color: color, electric: rental.isElectric),
            const SizedBox(width: 8),
            if (pickupAge != null)
              Expanded(
                child: Text(formatUpdatedAgo(pickupAge, l10n),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
              ),
          ],
        ),
        stationCard(
          key: const ValueKey('rental-pickup'),
          title: l10n.rentalPickup(pickup?.name ?? leg.from.name),
          st: pickup,
          isPickup: true,
        ),
        const SizedBox(height: 6),
        Text(l10n.rentalRide(formatDuration(leg.durationSeconds, l10n), formatDistance(leg.distanceMeters)),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        stationCard(
          key: const ValueKey('rental-dropoff'),
          title: l10n.rentalDropoff(dropoff?.name ?? leg.to.name),
          st: dropoff,
          isPickup: false,
        ),
        if (price != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.payments_outlined, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(l10n.rentalPriceLine(formatMoney(price.amount, price.currency, locale), price.label ?? rental.networkName),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurface)),
            ],
          ),
        ],
        if (appLink != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextButton.icon(
              key: const ValueKey('rental-open-app'),
              style: TextButton.styleFrom(foregroundColor: color, padding: EdgeInsets.zero, minimumSize: const Size(44, 36)),
              onPressed: () async {
                try {
                  await launchUrl(appLink, mode: LaunchMode.externalApplication);
                } catch (_) {}
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(l10n.openApp(network!.name)),
            ),
          ),
      ],
    );
  }
}

/// Taxi / ride-hailing leg: kind chip, ride summary, the provider picker
/// with "Pedir" buttons, the tariff source line and surcharge chips (v1.4).
class _OnDemandLegBody extends ConsumerWidget {
  const _OnDemandLegBody({required this.cityId, required this.leg, required this.onDemand, required this.color});
  final String cityId;
  final Leg leg;
  final LegOnDemand onDemand;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final city = ref.watch(currentCityProvider);
    final rec = onDemand.recommended;
    final isTaxi = (city?.mobility.provider(rec?.providerId)?.kind ?? onDemand.displayKind) == 'taxi';
    final tariffProvider = onDemand.providers
        .map((o) => city?.mobility.provider(o.providerId))
        .whereType<OnDemandProvider>()
        .where((p) => p.estimateKind == 'tariff')
        .firstOrNull;
    final tariff = tariffProvider == null ? null : city?.mobility.tariff(tariffProvider.tariffId);
    final tariffPrice = onDemand.providers.where((o) => o.source == 'tariff').firstOrNull?.price;

    return Column(
      key: const ValueKey('ondemand-leg'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OnDemandChip(name: isTaxi ? l10n.onDemandTaxi : l10n.onDemandRidehail, color: color, taxi: isTaxi),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l10n.requestVehicleTo(leg.to.name),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(rideSummary(leg, l10n), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(l10n.chooseProvider, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
        ProviderPicker(
          cityId: cityId,
          from: leg.from,
          to: leg.to,
          options: onDemand.providers,
          recommendedId: rec?.providerId,
        ),
        TariffFootnote(tariff: tariff, price: tariffPrice),
      ],
    );
  }
}

IconData _stepIcon(String? dir) => switch (dir) {
      'LEFT' || 'SLIGHTLY_LEFT' || 'HARD_LEFT' => Icons.turn_left,
      'RIGHT' || 'SLIGHTLY_RIGHT' || 'HARD_RIGHT' => Icons.turn_right,
      'UTURN_LEFT' || 'UTURN_RIGHT' => Icons.u_turn_left,
      'DEPART' => Icons.trip_origin,
      _ => Icons.straight,
    };

/// Dotted connector for walking legs. A CustomPaint (not a LayoutBuilder) so
/// it can live inside the IntrinsicHeight row: LayoutBuilder has no intrinsic
/// size and would throw during the timeline's layout.
class _DottedBar extends StatelessWidget {
  const _DottedBar({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 6, child: CustomPaint(painter: _DotsPainter(color)));
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var y = 4.0; y < size.height; y += 8) {
      canvas.drawCircle(Offset(size.width / 2, y), 2, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color;
}

class _EndTile extends StatelessWidget {
  const _EndTile({required this.place, required this.time});
  final Place place;
  final DateTime time;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 48, child: Text(formatClock(time, locale), style: const TextStyle(fontWeight: FontWeight.w700))),
        Container(width: 14, height: 14, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFC62828))),
        const SizedBox(width: 14),
        Expanded(child: Text(l10n.arriveAt(place.name), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
      ],
    );
  }
}
