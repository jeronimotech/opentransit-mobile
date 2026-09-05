import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import 'fare.dart';

/// `ios | android | web` for the `platform` hand-off parameter.
String handoffPlatform({bool? isIos, bool? isAndroid}) {
  if (kIsWeb) return 'web';
  if (isIos ?? Platform.isIOS) return 'ios';
  if (isAndroid ?? Platform.isAndroid) return 'android';
  return 'web';
}

/// Appends (or replaces) `platform=` on an API hand-off URL.
Uri handoffUri(String url, {String? platform, bool? isIos}) {
  final u = Uri.parse(url);
  final q = Map<String, String>.from(u.queryParameters)..['platform'] = platform ?? handoffPlatform(isIos: isIos);
  return u.replace(queryParameters: q);
}

/// Store link for this platform, else the provider's website. Null when neither.
Uri? providerFallbackLink(OnDemandProvider p, {bool? isIos}) {
  final ios = isIos ?? (!kIsWeb && Platform.isIOS);
  final link = ios ? p.appIos : p.appAndroid;
  final s = (link != null && link.isNotEmpty) ? link : p.web;
  return s == null || s.isEmpty ? null : Uri.tryParse(s);
}

/// Providers sorted for a picker: the recommended one first, then priced
/// options by price, then the rest in their configured order.
List<OnDemandOption> sortOptions(List<OnDemandOption> options, {String? recommendedId, City? city}) {
  int orderOf(OnDemandOption o) => city?.mobility.provider(o.providerId)?.order ?? 1 << 20;
  final list = [...options];
  list.sort((a, b) {
    if (a.providerId == recommendedId) return -1;
    if (b.providerId == recommendedId) return 1;
    final pa = a.price?.amount, pb = b.price?.amount;
    if (pa != null && pb != null && pa != pb) return pa.compareTo(pb);
    if (pa != null && pb == null) return -1;
    if (pa == null && pb != null) return 1;
    return orderOf(a).compareTo(orderOf(b));
  });
  return list;
}

/// "≈ $ 18.000–22.000" when the band is meaningful, else "≈ $ 20.000".
String formatPriceRange(OnDemandPrice p, String locale) {
  final approx = p.estimated ? '≈ ' : '';
  if (p.hasRange) {
    final a = formatMoney(p.min!, p.currency, locale);
    final b = formatMoney(p.max!, p.currency, locale);
    // Drop the repeated currency symbol on the upper bound: "$ 18.000–22.000".
    final sym = a.split(' ').first;
    final bShort = b.startsWith('$sym ') ? b.substring(sym.length + 1) : b;
    return '$approx$a–$bShort';
  }
  return '$approx${formatMoney(p.amount, p.currency, locale)}';
}

/// Label for the planner chip: generic for a city with a taxi and apps, the
/// provider name when a city has exactly one.
String onDemandChipLabel(City city, String generic) {
  final ps = city.mobility.onDemandProviders;
  return ps.length == 1 ? ps.first.name : generic;
}

/// Taxi fare from a regulated tariff — mirrors the API rule so the mock and
/// tests share one implementation: flag fall + distance units + waiting
/// units, never below the minimum, plus the night/Sunday surcharge when
/// [at] falls inside the configured window. ±10 % band for traffic.
OnDemandPrice? estimateTaxiFare(TaxiTariff? t, int distanceMeters, int durationSeconds, DateTime at,
    {bool airport = false, bool doorToDoor = false, Set<String>? holidays}) {
  if (t == null) return null;
  final distUnits = (distanceMeters / t.unitMeters).ceil();
  // Waiting time: the share of the ride spent below the "unit" speed is
  // unknown, so charge only the time above a free-flow ride at 30 km/h.
  final freeFlowSecs = distanceMeters / (30 * 1000 / 3600);
  final waitUnits = math.max(0, ((durationSeconds - freeFlowSecs) / t.unitSeconds).floor());
  num fare = t.flagFall + (distUnits + waitUnits) * t.unitPrice;
  if (fare < t.minimumFare) fare = t.minimumFare;
  final lines = <TariffSurcharge>[
    TariffSurcharge(id: 'base', label: t.name, amount: fare),
  ];
  final applied = <String>[];
  final night = t.surcharge('night');
  if (night != null && isNightOrHoliday(at, holidays: holidays)) {
    fare += night.amount;
    lines.add(night);
    applied.add(night.id);
  }
  final ap = t.surcharge('airport');
  if (airport && ap != null) {
    fare += ap.amount;
    lines.add(ap);
    applied.add(ap.id);
  }
  final door = t.surcharge('door');
  if (doorToDoor && door != null) {
    fare += door.amount;
    lines.add(door);
    applied.add(door.id);
  }
  final rounded = (fare / 100).round() * 100;
  return OnDemandPrice(
    amount: rounded,
    min: ((rounded * 0.9) / 100).round() * 100,
    max: ((rounded * 1.1) / 100).round() * 100,
    currency: t.currency,
    estimated: true,
    breakdown: lines,
    surchargesApplied: applied,
  );
}

/// Night (19:00–06:00), Sunday, or a configured holiday (`yyyy-MM-dd`).
bool isNightOrHoliday(DateTime at, {Set<String>? holidays}) {
  if (at.hour >= 19 || at.hour < 6) return true;
  if (at.weekday == DateTime.sunday) return true;
  final key = '${at.year.toString().padLeft(4, '0')}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
  return holidays?.contains(key) ?? false;
}

/// Names OTP leaves on raw coordinates; never worth sending to a provider.
const _genericNames = {'origin', 'destination', 'origen', 'destino', ''};

/// A place name worth prefilling in the provider's app, else null (the API
/// then reverse-geocodes or omits it).
String? placeLabel(Place? p) {
  final n = p?.name.trim() ?? '';
  return _genericNames.contains(n.toLowerCase()) ? null : n;
}

/// Uses the names the user typed for the trip's endpoints when a leg's own
/// place carries a generic name.
List<Leg> legsWithEndpointNames(Itinerary it, {String? fromName, String? toName}) {
  if (it.legs.isEmpty) return it.legs;
  return [
    for (var i = 0; i < it.legs.length; i++)
      it.legs[i].copyWith(
        from: i == 0 && placeLabel(it.legs[i].from) == null && fromName != null
            ? it.legs[i].from.copyWith(name: fromName)
            : null,
        to: i == it.legs.length - 1 && placeLabel(it.legs[i].to) == null && toName != null
            ? it.legs[i].to.copyWith(name: toName)
            : null,
      ),
  ];
}

/// Requests a ride: fetches the hand-off JSON from the API (credentials are
/// injected server-side), then launches the returned provider URL in the
/// external app (a universal link opens the provider app directly). Never
/// navigates to the API endpoint itself. Falls back to the store / website
/// when the link cannot be opened. Returns `link | fallback | none`.
Future<String> requestRide({
  required ApiClient api,
  required String cityId,
  required String providerId,
  required Place from,
  required Place to,
  OnDemandProvider? provider,
  String? platform,
  Future<bool> Function(Uri)? launcher,
  Future<bool> Function(Uri)? canLaunch,
}) async {
  final launch = launcher ?? ((u) => launchUrl(u, mode: LaunchMode.externalApplication));
  final can = canLaunch ?? canLaunchUrl;
  Uri? fallback = provider == null ? null : providerFallbackLink(provider);
  try {
    final h = await api.onDemandHandoff(
      cityId, providerId, from.position, to.position,
      fromName: placeLabel(from), toName: placeLabel(to),
      platform: platform ?? handoffPlatform(),
    );
    final fb = h.fallback == null ? null : Uri.tryParse(h.fallback!);
    if (fb != null) fallback = fb;
    final u = h.url.isEmpty ? null : Uri.tryParse(h.url);
    if (u != null) {
      // https universal links are always launchable; custom schemes only when
      // the provider app is installed (needs LSApplicationQueriesSchemes on iOS).
      final web = u.scheme == 'http' || u.scheme == 'https';
      if ((web || await can(u)) && await launch(u)) return 'link';
    }
  } catch (_) {
    // API unreachable or invalid response: fall through to the store / website.
  }
  if (fallback != null) {
    try {
      if (await launch(fallback)) return 'fallback';
    } catch (_) {}
  }
  return 'none';
}
