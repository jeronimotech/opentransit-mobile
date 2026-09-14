import 'package:flutter/material.dart';

import 'common.dart';

/// v1.6 — paid on-street parking (CDS curb zones; in Bogotá the ZPP kerbs PIM
/// publishes) and park & ride.

/// A curb zone as `/curbs` describes it, evaluated for a car right now.
class CurbZone {
  const CurbZone({
    required this.id,
    this.name,
    this.streetName,
    required this.position,
    this.availableSpaces,
    this.totalSpaces,
    this.occupancyRate,
    this.available,
    this.availabilityTime,
    this.priceLabel,
    this.allowed,
    this.whyLegal,
    this.nextChange,
    this.distanceMeters,
  });
  final String id;
  final String? name;
  final String? streetName;

  /// The zone's centre (kerbs are 40–60 m lines; a point is what a phone can tap).
  final LatLng position;
  final int? availableSpaces;
  final int? totalSpaces;
  final double? occupancyRate;
  final bool? available;

  /// When the operator last counted; PIM's counts are hours old, and the UI says so.
  final DateTime? availabilityTime;
  final String? priceLabel;

  /// Whether a car may park here right now; null when no policy speaks of cars.
  final bool? allowed;
  final String? whyLegal;
  final DateTime? nextChange;
  final int? distanceMeters;

  String get title => name ?? streetName ?? id;

  int? ageSeconds({DateTime? now}) => availabilityTime == null
      ? null
      : (now ?? DateTime.now()).difference(availabilityTime!).inSeconds.clamp(0, 1 << 30);

  ParkingTone get tone => parkingTone(available: availableSpaces, total: totalSpaces, allowed: allowed);

  factory CurbZone.fromJson(Map<String, dynamic> j) {
    final c = j['center'] is Map ? Map<String, dynamic>.from(j['center'] as Map) : null;
    return CurbZone(
      id: j['id'].toString(),
      name: j['name']?.toString(),
      streetName: j['streetName']?.toString(),
      position: c == null ? const LatLng(0, 0) : LatLng(asDouble(c['lat']) ?? 0, asDouble(c['lon']) ?? 0),
      availableSpaces: asInt(j['availableSpaces']),
      totalSpaces: asInt(j['totalSpaces']),
      occupancyRate: asDouble(j['occupancyRate']),
      available: j['available'] is bool ? j['available'] as bool : null,
      availabilityTime: parseTime(j['availabilityTime']),
      priceLabel: j['priceLabel']?.toString(),
      allowed: j['allowed'] is bool ? j['allowed'] as bool : null,
      whyLegal: j['whyLegal']?.toString(),
      nextChange: parseTime(j['nextChange']),
      distanceMeters: asInt(j['distanceMeters']),
    );
  }
}

/// The parking fee an itinerary assumes, for the city's default dwell.
class ParkingFee {
  const ParkingFee({required this.amount, required this.currency, required this.dwellHours, this.estimated = true});
  final num amount;
  final String currency;
  final double dwellHours;
  final bool estimated;

  factory ParkingFee.fromJson(Map<String, dynamic> j) => ParkingFee(
        amount: (j['amount'] as num?) ?? 0,
        currency: j['currency']?.toString() ?? '',
        dwellHours: asDouble(j['dwellHours']) ?? 0,
        estimated: j['estimated'] is bool ? j['estimated'] as bool : true,
      );
}

/// Where a park & ride itinerary leaves the car (`itinerary.parking`).
class ParkingInfo {
  const ParkingInfo({
    required this.curbZoneId,
    this.name,
    this.streetName,
    required this.position,
    this.availableSpaces,
    this.totalSpaces,
    this.availabilityTime,
    this.priceLabel,
    this.whyLegal,
    this.allowedUntil,
    this.fee,
    this.walkMeters = 0,
    this.walkSeconds = 0,
  });
  final String curbZoneId;
  final String? name;
  final String? streetName;
  final LatLng position;
  final int? availableSpaces;
  final int? totalSpaces;
  final DateTime? availabilityTime;
  final String? priceLabel;
  final String? whyLegal;
  final DateTime? allowedUntil;
  final ParkingFee? fee;
  final int walkMeters;
  final int walkSeconds;

  String get title => name ?? streetName ?? curbZoneId;

  int? ageSeconds({DateTime? now}) => availabilityTime == null
      ? null
      : (now ?? DateTime.now()).difference(availabilityTime!).inSeconds.clamp(0, 1 << 30);

  ParkingTone get tone => parkingTone(available: availableSpaces, total: totalSpaces, allowed: true);

  factory ParkingInfo.fromJson(Map<String, dynamic> j) => ParkingInfo(
        curbZoneId: j['curbZoneId'].toString(),
        name: j['name']?.toString(),
        streetName: j['streetName']?.toString(),
        position: LatLng(asDouble(j['lat']) ?? 0, asDouble(j['lon']) ?? 0),
        availableSpaces: asInt(j['availableSpaces']),
        totalSpaces: asInt(j['totalSpaces']),
        availabilityTime: parseTime(j['availabilityTime']),
        priceLabel: j['priceLabel']?.toString(),
        whyLegal: j['whyLegal']?.toString(),
        allowedUntil: parseTime(j['allowedUntil']),
        fee: j['fee'] is Map ? ParkingFee.fromJson(Map<String, dynamic>.from(j['fee'] as Map)) : null,
        walkMeters: asInt(j['walkMeters']) ?? 0,
        walkSeconds: asInt(j['walkSeconds']) ?? 0,
      );
}

/// How a zone reads to a driver. `closed` beats everything (you may not park
/// now); then the count: none → full, fewer than three or under a fifth → low.
enum ParkingTone { ok, low, full, unknown, closed }

ParkingTone parkingTone({int? available, int? total, bool? allowed}) {
  if (allowed == false) return ParkingTone.closed;
  if (available == null) return ParkingTone.unknown;
  if (available <= 0) return ParkingTone.full;
  if (available < 3 || ((total ?? 0) > 0 && available / total! < 0.2)) return ParkingTone.low;
  return ParkingTone.ok;
}

/// The same five colours the web uses, so a zone looks the same on both.
Color parkingColor(ParkingTone t) => switch (t) {
      ParkingTone.ok => const Color(0xFF2E7D4F),
      ParkingTone.low => const Color(0xFFC77700),
      ParkingTone.full => const Color(0xFFB42318),
      ParkingTone.unknown => const Color(0xFF667085),
      ParkingTone.closed => const Color(0xFF98A2B3),
    };

/// The blue every park & ride surface uses for "your car".
const Color parkRideBlue = Color(0xFF1D4ED8);
