import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/models.dart';

/// Where "Abrir {name}" should go on this device: the store/app link for the
/// platform when the network ships one, else its website. Null when neither.
Uri? rentalAppLink(BikeShareNetwork n, {bool? isIos}) {
  final ios = isIos ?? (!kIsWeb && Platform.isIOS);
  final link = ios ? n.appIos : n.appAndroid;
  final s = (link != null && link.isNotEmpty) ? link : n.url;
  return s == null || s.isEmpty ? null : Uri.tryParse(s);
}

/// Label for the planner chip: "Bici pública" for a single network, the
/// network's own name when the city has several.
String bikeShareChipLabel(City city, String generic) =>
    city.mobility.bikeShare.length > 1 ? city.mobility.bikeShare.map((n) => n.name).join(' · ') : generic;

/// Adds/removes the rental request mode. The router understands `BIKE_RENTAL`
/// with or without transit; a scooter network adds `SCOOTER_RENTAL` too.
Set<TravelMode> withBikeShare(Set<TravelMode> modes, {required bool on, bool scooters = false}) {
  final next = {...modes};
  if (on) {
    next.add(TravelMode.bikeRental);
    if (scooters) next.add(TravelMode.scooterRental);
  } else {
    next.remove(TravelMode.bikeRental);
    next.remove(TravelMode.scooterRental);
  }
  return next;
}

/// "6 bicis · 2 eléctricas · 13 puestos" using the given short formatters.
String availabilitySummary(
  RentalStation s, {
  required String Function(int) bikes,
  required String Function(int) ebikes,
  required String Function(int) docks,
}) {
  final parts = <String>[
    if (s.vehiclesAvailable != null) bikes(s.vehiclesAvailable!),
    if ((s.ebikesAvailable ?? 0) > 0) ebikes(s.ebikesAvailable!),
    if (s.docksAvailable != null) docks(s.docksAvailable!),
  ];
  return parts.join(' · ');
}
