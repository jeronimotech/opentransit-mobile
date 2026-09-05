import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../api/api_client.dart';
import '../models/models.dart';
import '../providers.dart';
import '../utils/colors.dart';
import '../utils/fare.dart';
import '../utils/ondemand.dart';
import '../utils/service_window.dart';

/// Pill showing a route's short name in its brand colour, with the component
/// icon from the city's `components[]` palette.
class RouteChip extends ConsumerWidget {
  const RouteChip(this.route, {super.key, this.dense = false, this.mode});
  final RouteRef? route;
  final bool dense;

  /// Used for non-transit legs (walk, bike) when [route] is null.
  final TravelMode? mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = route;
    final city = ref.watch(currentCityProvider);
    final colors = r == null ? null : routeChipColors(r, city: city);
    final bg = colors?.bg ?? Theme.of(context).colorScheme.surfaceContainerHighest;
    final fg = colors?.fg ?? Theme.of(context).colorScheme.onSurfaceVariant;
    final icon = r == null
        ? modeIcon(mode ?? TravelMode.walk)
        : (r.mode == TravelMode.bus ? componentIcon(r.component, city: city) : modeIcon(r.mode));
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: dense ? 7 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 13 : 16, color: fg),
          if (r != null && r.shortName.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              r.shortName,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w800,
                fontSize: dense ? 12 : 14,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pill for a shared-bike leg: bike icon + the network's name, in the
/// network's colour (from `city.mobility.bikeShare[]`, never hardcoded).
class RentalChip extends StatelessWidget {
  const RentalChip({super.key, required this.name, required this.color, this.dense = false, this.electric = false});
  final String name;
  final Color color;
  final bool dense;
  final bool electric;

  @override
  Widget build(BuildContext context) {
    final bg = ensureContrast(color, Colors.white);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(electric ? Icons.electric_bike : Icons.pedal_bike, size: dense ? 13 : 16, color: onColor(bg)),
          const SizedBox(width: 4),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: onColor(bg), fontWeight: FontWeight.w800, fontSize: dense ? 12 : 14)),
        ],
      ),
    );
  }
}

/// Chip for a taxi / ride-hailing leg in the provider colour (v1.4).
class OnDemandChip extends StatelessWidget {
  const OnDemandChip({super.key, required this.name, required this.color, this.dense = false, this.taxi = true});
  final String name;
  final Color color;
  final bool dense;
  final bool taxi;

  @override
  Widget build(BuildContext context) {
    final bg = ensureContrast(color, Colors.white);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(taxi ? Icons.local_taxi_rounded : Icons.directions_car_rounded, size: dense ? 13 : 16, color: onColor(bg)),
          const SizedBox(width: 4),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: onColor(bg), fontWeight: FontWeight.w800, fontSize: dense ? 12 : 14)),
        ],
      ),
    );
  }
}

/// Square badge with the component icon in the component colour.
class ComponentBadge extends ConsumerWidget {
  const ComponentBadge(this.component, {super.key, this.size = 36, this.isStation = false});
  final Component? component;
  final double size;
  final bool isStation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city = ref.watch(currentCityProvider);
    final color = componentColor(component, city: city);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size * 0.28)),
      child: Icon(isStation ? Icons.subway_outlined : componentIcon(component, city: city),
          color: onColor(color), size: size * 0.55),
    );
  }
}

/// Small "live" indicator with a pulsing dot.
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = Colors.green.shade600;
    return Semantics(
      label: l10n.realtime,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Pulse(color: color),
            if (!compact) ...[
              const SizedBox(width: 4),
              Text(l10n.realtime,
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.color});
  final Color color;
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      if (_c.isAnimating) _c.stop();
      return dot;
    }
    if (!_c.isAnimating) _c.repeat(reverse: true);
    return FadeTransition(opacity: Tween(begin: 0.35, end: 1.0).animate(_c), child: dot);
  }
}

/// Data-freshness label driven by the city health endpoint:
/// "En vivo" · "Programado" · "Sin datos en vivo hace N s".
class FreshnessLabel extends ConsumerWidget {
  const FreshnessLabel({super.key, required this.cityId, this.realtime, this.freshness});
  final String cityId;

  /// Whether the item being labelled carries realtime data.
  final bool? realtime;

  /// Response-level freshness when available (boards, next buses).
  final Freshness? freshness;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final health = ref.watch(healthProvider(cityId)).asData?.value;
    final rt = health?.realtime;
    final stale = freshness?.stale ?? rt?.isStale ?? false;
    final age = freshness?.ageSeconds ?? rt?.ageSeconds;
    if (stale) {
      return _Label(
        color: Colors.orange.shade800,
        text: age == null ? l10n.freshNoRealtime : l10n.freshStale(age.clamp(0, 99999)),
      );
    }
    if (realtime ?? freshness?.realtime ?? false) return const LiveBadge();
    return _Label(color: scheme.outline, text: l10n.freshScheduled);
  }
}

/// Dot + text, the single freshness style used across the app (§E).
class _Label extends StatelessWidget {
  const _Label({required this.color, required this.text});
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Semantics(
        label: text,
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
}

/// "Fuera de horario · próximo 04:30" / "Sin servicio hoy"; nothing while active.
class ServiceHint extends StatelessWidget {
  const ServiceHint(this.window, {super.key, this.dense = false});
  final ServiceWindow? window;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hint = serviceHint(window,
        outOfHours: l10n.outOfHours, nextAt: l10n.nextAt, noMoreToday: l10n.noServiceToday);
    if (hint == null) return const SizedBox.shrink();
    final color = Colors.orange.shade800;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.nightlight_round, size: dense ? 12 : 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: dense ? 11 : 12, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

/// "Tarifa estimada · $ 3.200" (or "Tarifa no publicada").
class FareText extends ConsumerWidget {
  const FareText(this.itinerary, {super.key, this.style});
  final Itinerary itinerary;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final city = ref.watch(currentCityProvider);
    final fare = fareFor(itinerary, city);
    final base = style ?? Theme.of(context).textTheme.labelMedium;
    // On-demand itineraries (v1.4): show the ride's price band when known,
    // else "Precio en la app".
    final od = itinerary.onDemand;
    if (od != null && itinerary.isOnDemandDirect) {
      final p = od.displayPrice;
      return Text(p != null ? formatPriceRange(p, locale) : l10n.priceInApp,
          style: base?.copyWith(fontWeight: FontWeight.w700, color: p == null ? Theme.of(context).colorScheme.outline : null));
    }
    if (fare == null) {
      return Text(l10n.fareNotPublished, style: base?.copyWith(color: Theme.of(context).colorScheme.outline));
    }
    if (fare.amount == null) {
      return Text(fare.note ?? l10n.priceInApp, style: base?.copyWith(color: Theme.of(context).colorScheme.outline));
    }
    final amount = formatMoney(fare.amount!, fare.currency, locale);
    return Text(fare.estimated ? '≈ $amount' : amount, style: base?.copyWith(fontWeight: FontWeight.w700));
  }
}

/// Full-bleed error state with retry.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final e = error;
    final msg = e is ApiException
        ? (e.isNetwork ? l10n.errorOffline : e.message)
        : l10n.errorGeneric;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(msg, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: onRetry, child: Text(l10n.retry)),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(text,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            ?trailing,
          ],
        ),
      );
}

String componentLabel(Component? c, AppLocalizations l10n, {City? city}) {
  final style = city?.componentStyle(c);
  if (style != null && style.label.isNotEmpty) return style.label;
  return switch (c) {
    Component.trunk => l10n.componentTrunk,
    Component.feeder => l10n.componentFeeder,
    Component.dual => l10n.componentDual,
    Component.zonal => l10n.componentZonal,
    Component.cable => l10n.componentCable,
    Component.rail => l10n.componentRail,
    _ => l10n.componentOther,
  };
}

String modeLabel(TravelMode m, AppLocalizations l10n) => switch (m) {
      TravelMode.walk => l10n.modeWalk,
      TravelMode.bus => l10n.modeBus,
      TravelMode.rail => l10n.modeRail,
      TravelMode.subway => l10n.modeSubway,
      TravelMode.tram => l10n.modeTram,
      TravelMode.cableCar => l10n.modeCableCar,
      TravelMode.bicycle => l10n.modeBicycle,
      TravelMode.car => l10n.modeCar,
      TravelMode.ferry => l10n.modeFerry,
      TravelMode.transit => l10n.modeTransit,
      TravelMode.bikeRental => l10n.modeBikeShare,
      TravelMode.scooterRental || TravelMode.scooter => l10n.modeScooter,
    };

String poiLabel(String type, AppLocalizations l10n) => switch (type) {
      'bike_parking' => l10n.poiBikeParking,
      'toilets' => l10n.poiToilets,
      'atm' => l10n.poiAtm,
      'health' => l10n.poiHealth,
      'library' => l10n.poiLibrary,
      _ => l10n.poiOther,
    };

IconData poiIcon(String type) => switch (type) {
      'bike_parking' => Icons.pedal_bike_rounded,
      'toilets' => Icons.wc_rounded,
      'atm' => Icons.local_atm_rounded,
      'health' => Icons.medical_services_rounded,
      'library' => Icons.local_library_rounded,
      _ => Icons.place_rounded,
    };

Color poiColor(String type) => switch (type) {
      'bike_parking' => const Color(0xFF00897B),
      'toilets' => const Color(0xFF5E35B1),
      'atm' => const Color(0xFF3949AB),
      'health' => const Color(0xFFE53935),
      'library' => const Color(0xFF6D4C41),
      _ => const Color(0xFF757575),
    };

/// Short text drawn inside a POI marker (symbol layer, no emoji needed).
String poiGlyph(String type) => switch (type) {
      'bike_parking' => 'B',
      'toilets' => 'WC',
      'atm' => r'$',
      'health' => '+',
      'library' => 'L',
      _ => '•',
    };

/// Icon for an alert severity.
Widget alertIcon(AlertSeverity s, {double size = 22}) => switch (s) {
      AlertSeverity.severe => Icon(Icons.error_rounded, color: Colors.red.shade700, size: size),
      AlertSeverity.warning => Icon(Icons.warning_rounded, color: Colors.orange.shade800, size: size),
      AlertSeverity.info => Icon(Icons.info_rounded, color: Colors.blue.shade700, size: size),
    };
