import 'package:flutter/material.dart';

import '../models/common.dart';

/// Parses `#RRGGBB` / `RRGGBB` / `#AARRGGBB`; falls back to [fallback].
Color colorFromHex(String? hex, {Color fallback = const Color(0xFF607D8B)}) {
  if (hex == null) return fallback;
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return fallback;
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}

Color componentColor(Component? c) => switch (c) {
      Component.trunk => const Color(0xFFD32F2F),
      Component.feeder => const Color(0xFF2E7D32),
      Component.dual => const Color(0xFF6A1B9A),
      Component.zonal => const Color(0xFF1565C0),
      Component.cable => const Color(0xFFEF6C00),
      Component.rail => const Color(0xFF00838F),
      _ => const Color(0xFF607D8B),
    };

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

/// Readable text colour on top of [bg].
Color onColor(Color bg) =>
    bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
