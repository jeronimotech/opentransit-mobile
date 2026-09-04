import 'package:flutter/material.dart';

import '../utils/colors.dart';

/// How live vehicles are drawn at a given zoom (UX audit §B).
enum VehicleMarkerMode {
  /// Below city zoom nothing is drawn unless a route or stop is selected.
  hidden,

  /// Street-district zoom: small translucent dots.
  small,

  /// Street zoom: larger dots with a bearing tick and the route label.
  large,
}

class VehicleMarkerStyle {
  const VehicleMarkerStyle({
    required this.mode,
    required this.radius,
    required this.opacity,
    required this.strokeWidth,
    required this.showBearing,
    required this.showLabel,
  });
  final VehicleMarkerMode mode;
  final double radius;
  final double opacity;
  final double strokeWidth;
  final bool showBearing;
  final bool showLabel;

  bool get visible => mode != VehicleMarkerMode.hidden;
}

const double liveMinZoom = 14;
const double liveDetailZoom = 16;

/// Zoom → marker style. [selected] (a route or stop is focused) keeps vehicles
/// visible at any zoom and always at full size.
VehicleMarkerStyle vehicleMarkerStyle(double zoom, {bool selected = false}) {
  if (selected) {
    return const VehicleMarkerStyle(
        mode: VehicleMarkerMode.large, radius: 6, opacity: 1, strokeWidth: 1.5, showBearing: true, showLabel: true);
  }
  if (zoom < liveMinZoom) {
    return const VehicleMarkerStyle(
        mode: VehicleMarkerMode.hidden, radius: 0, opacity: 0, strokeWidth: 0, showBearing: false, showLabel: false);
  }
  if (zoom < liveDetailZoom) {
    return const VehicleMarkerStyle(
        mode: VehicleMarkerMode.small, radius: 3, opacity: 0.7, strokeWidth: 0.8, showBearing: false, showLabel: false);
  }
  return const VehicleMarkerStyle(
      mode: VehicleMarkerMode.large, radius: 5, opacity: 0.95, strokeWidth: 1.2, showBearing: true, showLabel: true);
}

/// Component colour as drawn on the map: 20 % desaturated (§B).
Color mapVehicleColor(Color component, {bool selected = false}) =>
    selected ? component : desaturate(component, 0.2);

/// Colour of a route shape on the home map: neon feed colours use the
/// component colour; then desaturated 35 % and drawn at 45 % opacity.
Color networkLineColor(String? feedHex, Color component, {bool backbone = true}) {
  final feed = colorFromHex(feedHex, fallback: component);
  final base = isNeonColor(feed) || feedHex == null || feedHex.isEmpty ? component : feed;
  // Zonal corridors stack dozens of overlapping shapes: draw them fainter.
  return desaturate(base, 0.35).withValues(alpha: backbone ? 0.5 : 0.18);
}

// ───────────────────────── v1.2 shared-bike stations ─────────────────────────

/// How docking stations are drawn at a given zoom: hidden below 14, small
/// rings 14–15, rings with the available count from 15 (contract "Clients").
class RentalMarkerStyle {
  const RentalMarkerStyle({required this.visible, required this.radius, required this.showCount, required this.strokeWidth});
  final bool visible;
  final double radius;
  final bool showCount;
  final double strokeWidth;
}

const double rentalMinZoom = 14;
const double rentalCountZoom = 15;

RentalMarkerStyle rentalMarkerStyle(double zoom) {
  if (zoom < rentalMinZoom) {
    return const RentalMarkerStyle(visible: false, radius: 0, showCount: false, strokeWidth: 0);
  }
  if (zoom < rentalCountZoom) {
    return const RentalMarkerStyle(visible: true, radius: 6, showCount: false, strokeWidth: 2.5);
  }
  return const RentalMarkerStyle(visible: true, radius: 11, showCount: true, strokeWidth: 3);
}

/// Ring colour for a station: the network colour when bikes are available,
/// amber when only one or two are left, grey when empty or not renting.
Color rentalRingColor(int? bikes, Color network, {bool renting = true}) {
  if (!renting || bikes == null || bikes <= 0) return const Color(0xFF9E9E9E);
  if (bikes <= 2) return const Color(0xFFF9A825);
  return network;
}
