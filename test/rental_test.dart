// v1.2 shared bikes: rental leg parsing, request modes, availability text,
// marker style by zoom, fare with rental passes, N networks per city.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/api/mock_api_client.dart';
import 'package:opentransit_mobile/core/live/marker_style.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/utils/fare.dart';
import 'package:opentransit_mobile/core/utils/rental.dart';

import 'helpers/fixtures.dart';

void main() {
  final cities = (loadFixture('cities')['cities'] as List)
      .map((e) => City.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  final bogota = cities.firstWhere((c) => c.id == 'bogota');
  final medellin = cities.firstWhere((c) => c.id == 'medellin');
  final rental = (loadFixture('plan_rental')['itineraries'] as List)
      .map((e) => Itinerary.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();

  group('city mobility config', () {
    test('networks are per city and there can be several', () {
      expect(bogota.bikeShareEnabled, isTrue);
      expect(bogota.mobility.bikeShare, hasLength(1));
      expect(medellin.mobility.bikeShare.map((n) => n.name), ['EnCicla', 'Movo']);
      expect(medellin.mobility.network('movo')?.color, '#7B1FA2');
      expect(medellin.mobility.network('movo')?.hasScooters, isTrue);
      expect(medellin.mobility.network('unknown')?.id, 'encicla', reason: 'unknown id falls back to the first network');
    });

    test('chip label is generic for one network and lists names for several', () {
      expect(bikeShareChipLabel(bogota, 'Bici pública'), 'Bici pública');
      expect(bikeShareChipLabel(medellin, 'Bici pública'), 'EnCicla · Movo');
    });

    test('feature flag off or no networks disables the module', () {
      final off = City.fromJson({'id': 'x', 'name': 'X', 'features': {'bikeShare': true}});
      expect(off.bikeShareEnabled, isFalse, reason: 'no networks configured');
      final flagOff = City.fromJson({
        'id': 'y', 'name': 'Y', 'features': {'bikeShare': false},
        'mobility': {'bikeShare': [{'id': 'a', 'name': 'A'}]},
      });
      expect(flagOff.bikeShareEnabled, isFalse);
    });

    test('app link prefers the platform store link, then the website', () {
      final n = bogota.mobility.bikeShare.first;
      expect(rentalAppLink(n, isIos: true).toString(), n.appIos);
      expect(rentalAppLink(n, isIos: false).toString(), n.appAndroid);
      final web = medellin.mobility.network('encicla')!;
      expect(rentalAppLink(web, isIos: true).toString(), web.url);
      expect(rentalAppLink(const BikeShareNetwork(id: 'z', name: 'Z'), isIos: true), isNull);
    });
  });

  group('rental legs', () {
    test('parse the rental block, stations and price', () {
      final direct = rental.first;
      expect(direct.hasRental, isTrue);
      expect(direct.rentalLegs, 1);
      expect(direct.modesUsed, contains('BICYCLE_RENTAL'));
      final leg = direct.legs[1];
      expect(leg.mode, TravelMode.bicycle);
      expect(leg.transit, isFalse);
      expect(leg.isRental, isTrue);
      expect(leg.rental!.networkName, 'Tembici Bogotá');
      expect(leg.rental!.pickup!.vehiclesAvailable, 6);
      expect(leg.rental!.dropoff!.docksAvailable, 4);
      expect(leg.rental!.priceEstimate!.amount, 11000);
      expect(leg.from.rentalStationId, 'tembici:12');
      expect(leg.colorHex, '#00A859');
    });

    test('non-rental legs have no rental block and walking has no colour', () {
      final walk = rental.first.legs.first;
      expect(walk.isRental, isFalse);
      expect(walk.rental, isNull);
      expect(walk.colorHex, isNull);
    });

    test('fare breakdown carries kinds', () {
      final mixed = rental[1];
      expect(mixed.fare!.breakdown.map((l) => l.kind), ['transit', 'rental']);
      expect(mixed.fare!.breakdown.last.isRental, isTrue);
      expect(mixed.fare!.amount, 14200);
    });
  });

  group('request modes', () {
    test('BIKE_RENTAL is sent on the wire and is not a transit mode', () {
      const req = PlanRequest(
        from: Place(name: 'a', position: LatLng(4.6766, -74.0483)),
        to: Place(name: 'b', position: LatLng(4.6841, -74.0517)),
        modes: [TravelMode.walk, TravelMode.bikeRental],
      );
      expect(req.toQuery()['modes'], 'WALK,BIKE_RENTAL');
      expect(TravelMode.bikeRental.isTransit, isFalse);
      expect(TravelMode.bikeRental.isRental, isTrue);
      expect(TravelMode.parse('BIKE_RENTAL'), TravelMode.bikeRental);
      expect(TravelMode.parse('SCOOTER_RENTAL'), TravelMode.scooterRental);
    });

    test('withBikeShare toggles rental modes and adds scooters when offered', () {
      final base = {TravelMode.transit, TravelMode.walk};
      final on = withBikeShare(base, on: true);
      expect(on, containsAll([TravelMode.transit, TravelMode.walk, TravelMode.bikeRental]));
      expect(on.contains(TravelMode.scooterRental), isFalse);
      final scoot = withBikeShare(base, on: true, scooters: true);
      expect(scoot, contains(TravelMode.scooterRental));
      final off = withBikeShare(scoot, on: false);
      expect(off, base);
    });
  });

  group('availability formatting', () {
    String bikes(int n) => '$n bicis';
    String ebikes(int n) => '$n eléctricas';
    String docks(int n) => '$n puestos';
    const st = RentalStation(id: 's', name: 'S', position: LatLng(0, 0), vehiclesAvailable: 6, ebikesAvailable: 2, docksAvailable: 13);

    test('lists bikes, e-bikes and docks', () {
      expect(availabilitySummary(st, bikes: bikes, ebikes: ebikes, docks: docks), '6 bicis · 2 eléctricas · 13 puestos');
    });

    test('omits e-bikes when none and unknown counts', () {
      const none = RentalStation(id: 's', name: 'S', position: LatLng(0, 0), vehiclesAvailable: 0, ebikesAvailable: 0, docksAvailable: 19);
      expect(availabilitySummary(none, bikes: bikes, ebikes: ebikes, docks: docks), '0 bicis · 19 puestos');
      const unknown = RentalStation(id: 's', name: 'S', position: LatLng(0, 0));
      expect(availabilitySummary(unknown, bikes: bikes, ebikes: ebikes, docks: docks), '');
      expect(none.canRent, isFalse);
      expect(none.canReturn, isTrue);
      expect(st.ageSeconds(), isNull);
    });

    test('age is computed from lastReported', () {
      final s = RentalStation(id: 's', name: 'S', position: const LatLng(0, 0), lastReported: DateTime(2026, 9, 4, 8));
      expect(s.ageSeconds(now: DateTime(2026, 9, 4, 8, 0, 42)), 42);
    });
  });

  group('marker style by zoom', () {
    test('hidden below 14, small rings 14–15, counted rings from 15', () {
      expect(rentalMarkerStyle(12).visible, isFalse);
      expect(rentalMarkerStyle(13.9).visible, isFalse);
      final small = rentalMarkerStyle(14.2);
      expect(small.visible, isTrue);
      expect(small.showCount, isFalse);
      final big = rentalMarkerStyle(15.5);
      expect(big.showCount, isTrue);
      expect(big.radius, greaterThan(small.radius));
    });

    test('ring colour reflects availability', () {
      const net = Color(0xFF00A859);
      expect(rentalRingColor(6, net), net);
      expect(rentalRingColor(2, net), const Color(0xFFF9A825));
      expect(rentalRingColor(0, net), const Color(0xFF9E9E9E));
      expect(rentalRingColor(6, net, renting: false), const Color(0xFF9E9E9E));
      expect(rentalRingColor(null, net), const Color(0xFF9E9E9E));
    });
  });

  group('fare with shared bikes', () {
    test('API fare is used when present', () {
      expect(fareFor(rental[1], bogota)!.amount, 14200);
    });

    test('estimate adds one pass per network on top of the transit fare', () {
      final it = rental[1];
      final stripped = Itinerary(
        id: it.id, startTime: it.startTime, endTime: it.endTime, durationSeconds: it.durationSeconds,
        walkDistanceMeters: it.walkDistanceMeters, walkTimeSeconds: it.walkTimeSeconds,
        waitingTimeSeconds: it.waitingTimeSeconds, transfers: it.transfers, legs: it.legs,
      );
      final f = estimateFare(stripped, bogota.fares)!;
      expect(f.amount, 3200 + 11000);
      expect(f.breakdown.map((l) => l.kind), ['transit', 'rental']);
      expect(f.breakdown.last.label, contains('Tembici'));
    });

    test('rental-only itinerary is priced even without city fares', () {
      final it = rental.first;
      final stripped = Itinerary(
        id: it.id, startTime: it.startTime, endTime: it.endTime, durationSeconds: it.durationSeconds,
        walkDistanceMeters: it.walkDistanceMeters, walkTimeSeconds: it.walkTimeSeconds,
        waitingTimeSeconds: it.waitingTimeSeconds, transfers: it.transfers, legs: it.legs,
      );
      final f = estimateFare(stripped, null)!;
      expect(f.amount, 11000);
      expect(f.currency, 'COP');
    });
  });

  group('mock client', () {
    final now = DateTime.parse('2026-10-10T15:30:00-05:00');
    MockApiClient client() => MockApiClient(bundle: DiskAssetBundle(), now: now, latency: Duration.zero);
    const from = Place(name: 'Parque de la 93', position: LatLng(4.6766, -74.0483));
    const to = Place(name: 'Calle 100', position: LatLng(4.6841, -74.0517));

    test('rental itineraries only appear when BIKE_RENTAL is requested', () async {
      final c = client();
      final plain = await c.plan('bogota', const PlanRequest(from: from, to: to));
      expect(plain.itineraries.any((i) => i.hasRental), isFalse);
      final mixed = await c.plan('bogota', const PlanRequest(from: from, to: to, modes: [TravelMode.transit, TravelMode.walk, TravelMode.bikeRental]));
      expect(mixed.itineraries.where((i) => i.hasRental), hasLength(2));
      expect(mixed.itineraries.length, plain.itineraries.length + 2);
      final direct = await c.plan('bogota', const PlanRequest(from: from, to: to, modes: [TravelMode.walk, TravelMode.bikeRental]));
      expect(direct.itineraries, hasLength(1));
      expect(direct.itineraries.single.legs.any((l) => l.transit), isFalse);
    });

    test('networks, stations, bbox filter and nearest', () async {
      final c = client();
      final nets = await c.rentalNetworks('bogota');
      expect(nets.single.pricingPlans, isNotEmpty);
      expect(nets.single.up, isTrue);
      final all = await c.rentalStations('bogota');
      expect(all.stations.length, 60);
      final box = await c.rentalStations('bogota', bbox: [-74.06, 4.67, -74.04, 4.69]);
      expect(box.stations.length, lessThan(all.stations.length));
      expect(box.stations.every((s) => s.position.lat >= 4.67 && s.position.lat <= 4.69), isTrue);
      final near = await c.nearbyRentalStations('bogota', const LatLng(4.6772, -74.0500), limit: 3);
      expect(near.first.id, 'tembici:12');
      expect(near.first.distanceMeters, lessThan(20));
      final detail = await c.rentalStation('bogota', 'tembici:12');
      expect(detail.network?.name, 'Tembici Bogotá');
      expect(detail.vehicleTypesAvailable.where((t) => (t.count ?? 0) > 0), isNotEmpty);
      // A city without the feature answers empty, never throws.
      expect(await c.rentalNetworks('medellin'), isNotEmpty, reason: 'medellin has the flag on');
    });

    test('health carries per-network rental status', () async {
      final h = await client().health('bogota');
      expect(h.rentalOf('tembici')?.up, isTrue);
      expect(h.rentalOf('tembici')?.stations, 60);
    });
  });
}
