import 'package:flutter/material.dart';

import '../models/models.dart';

/// Parses `#RRGGBB` / `RRGGBB` / `#AARRGGBB`; falls back to [fallback].
Color colorFromHex(String? hex, {Color fallback = const Color(0xFF607D8B)}) {
  if (hex == null) return fallback;
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return fallback;
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}

/// Default palette, used only when the city does not ship `components[]`.
Color _defaultComponentColor(Component? c) => switch (c) {
      Component.trunk => const Color(0xFFD32F2F),
      Component.feeder => const Color(0xFF2E7D32),
      Component.dual => const Color(0xFF6A1B9A),
      Component.zonal => const Color(0xFF1565C0),
      Component.cable => const Color(0xFFEF6C00),
      Component.rail => const Color(0xFF00838F),
      _ => const Color(0xFF607D8B),
    };

/// Colour for a component: the city's `components[]` entry wins.
Color componentColor(Component? c, {City? city}) {
  final style = city?.componentStyle(c);
  return style == null ? _defaultComponentColor(c) : colorFromHex(style.color, fallback: _defaultComponentColor(c));
}

/// Distinct icon per component (Troncal / Alimentador / Dual / Zonal / Cable).
IconData componentIcon(Component? c, {City? city}) {
  final hint = city?.componentStyle(c)?.icon;
  if (hint != null) {
    switch (hint) {
      case 'brt':
        return Icons.directions_bus_filled;
      case 'bus':
        return Icons.directions_bus_outlined;
      case 'cable':
        return Icons.cable;
      case 'rail':
        return Icons.train;
      case 'tram':
        return Icons.tram;
      case 'ferry':
        return Icons.directions_boat;
    }
  }
  return switch (c) {
    Component.trunk => Icons.directions_bus_filled,
    Component.feeder => Icons.airport_shuttle_outlined,
    Component.dual => Icons.merge_type,
    Component.zonal => Icons.directions_bus_outlined,
    Component.cable => Icons.cable,
    Component.rail => Icons.train,
    _ => Icons.directions_transit,
  };
}

IconData modeIcon(TravelMode m) => switch (m) {
      TravelMode.walk => Icons.directions_walk,
      TravelMode.bus => Icons.directions_bus,
      TravelMode.rail => Icons.train,
      TravelMode.subway => Icons.subway,
      TravelMode.tram => Icons.tram,
      TravelMode.cableCar => Icons.cable,
      TravelMode.bicycle => Icons.directions_bike,
      TravelMode.car => Icons.directions_car,
      TravelMode.ferry => Icons.directions_boat,
      TravelMode.transit => Icons.directions_transit,
      TravelMode.bikeRental => Icons.pedal_bike,
      TravelMode.scooterRental || TravelMode.scooter => Icons.electric_scooter,
    };

/// Material icon by name, for custom favorites and city service tiles.
IconData iconByName(String? name, {IconData fallback = Icons.star}) => switch (name) {
      'home' => Icons.home_rounded,
      'work' => Icons.work_rounded,
      'school' => Icons.school_rounded,
      'fitness_center' => Icons.fitness_center_rounded,
      'shopping_bag' => Icons.shopping_bag_rounded,
      'favorite' => Icons.favorite_rounded,
      'local_hospital' => Icons.local_hospital_rounded,
      'restaurant' => Icons.restaurant_rounded,
      'park' => Icons.park_rounded,
      'airport' => Icons.flight_rounded,
      'card' => Icons.credit_card_rounded,
      'help' => Icons.help_outline_rounded,
      'parking' => Icons.local_parking_rounded,
      'taxi' => Icons.local_taxi_rounded,
      'bike' => Icons.pedal_bike_rounded,
      'ticket' => Icons.confirmation_number_rounded,
      'star' => Icons.star_rounded,
      _ => fallback,
    };

/// Icon names offered when saving a custom favorite.
const customFavoriteIcons = [
  'star', 'school', 'fitness_center', 'shopping_bag', 'favorite',
  'local_hospital', 'restaurant', 'park', 'airport',
];

/// Readable text colour on top of [bg].
Color onColor(Color bg) =>
    bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

// ───────────────────────── v1.1.1 "map first" colour rules ─────────────────────────

/// Linear blend of [a] toward [b] by [t] (0 = a, 1 = b).
Color blendColors(Color a, Color b, double t) => Color.lerp(a, b, t.clamp(0, 1))!;

/// WCAG 2.x contrast ratio between two colours (1..21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Pure feed colours (`#FF0000`, `#00FF00`, `#0000FF`) that read as neon on a
/// map. The component colour is used instead of these.
bool isNeonColor(Color c) {
  final v = c.toARGB32() & 0xFFFFFF;
  return v == 0xFF0000 || v == 0x00FF00 || v == 0x0000FF;
}

/// Darkens or lightens [bg] until [fg] reaches at least [min] contrast on it.
Color ensureContrast(Color bg, Color fg, {double min = 4.5}) {
  if (contrastRatio(bg, fg) >= min) return bg;
  final towards = fg.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  var out = bg;
  for (var i = 1; i <= 20; i++) {
    out = Color.lerp(bg, towards, i / 20)!;
    if (contrastRatio(out, fg) >= min) return out;
  }
  return out;
}

/// Reduces saturation by [amount] (0..1) so map markers do not fight the base map.
Color desaturate(Color c, double amount) {
  final h = HSLColor.fromColor(c);
  return h.withSaturation((h.saturation * (1 - amount)).clamp(0, 1)).toColor();
}

/// Background + foreground for a route chip, per the v1.1.1 rule: the feed
/// colour blended 35 % toward the component colour and clamped to ≥ 4.5:1
/// contrast with its text; pure neon feed colours fall back to the component.
({Color bg, Color fg}) routeChipColors(RouteRef r, {City? city}) {
  final comp = componentColor(r.component, city: city);
  final feed = colorFromHex(r.color, fallback: comp);
  var bg = isNeonColor(feed) || r.color.isEmpty ? comp : blendColors(feed, comp, 0.35);
  final wanted = colorFromHex(r.textColor, fallback: onColor(bg));
  // A feed text colour that cannot reach contrast is replaced, not honoured.
  final fg = contrastRatio(bg, wanted) >= 3 ? wanted : onColor(bg);
  bg = ensureContrast(bg, fg);
  return (bg: bg, fg: fg);
}
