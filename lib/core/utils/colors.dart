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
