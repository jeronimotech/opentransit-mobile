import 'package:flutter/material.dart';

/// ETA bucket for a bus approaching the selected stop (TransMi-style).
enum EtaBucket { imminent, soon, later, far, unknown }

EtaBucket etaBucket(int? minutes) {
  if (minutes == null) return EtaBucket.unknown;
  if (minutes <= 5) return EtaBucket.imminent;
  if (minutes <= 10) return EtaBucket.soon;
  if (minutes <= 15) return EtaBucket.later;
  return EtaBucket.far;
}

Color etaColor(EtaBucket b) => switch (b) {
      EtaBucket.imminent => const Color(0xFF2E7D32),
      EtaBucket.soon => const Color(0xFFF9A825),
      EtaBucket.later => const Color(0xFFEF6C00),
      EtaBucket.far => const Color(0xFF78909C),
      EtaBucket.unknown => const Color(0xFF9E9E9E),
    };

/// Marker radius grows as the bus gets closer.
double etaRadius(EtaBucket b) => switch (b) {
      EtaBucket.imminent => 12,
      EtaBucket.soon => 10,
      EtaBucket.later => 9,
      _ => 7,
    };
