import 'common.dart';

/// On-demand mobility (taxi, ride-hailing) — v1.4 `city.mobility.onDemand[]`,
/// `city.mobility.taxiTariffs[]`, `leg.onDemand`, `/ondemand/*`.
///
/// Everything provider-specific (name, colour, links, template) comes from the
/// city configuration; nothing here knows any particular company.
class OnDemandProvider {
  const OnDemandProvider({
    required this.id,
    required this.name,
    this.kind = 'ridehail',
    this.color = '#455A64',
    this.textColor,
    this.logoUrl,
    this.estimateKind = 'none',
    this.tariffId,
    this.handoffKind = 'none',
    this.hasTemplate = false,
    this.web,
    this.appIos,
    this.appAndroid,
    this.scheme,
    this.enabled = true,
    this.order = 0,
  });
  final String id;
  final String name;

  /// `taxi | ridehail`
  final String kind;
  final String color;
  final String? textColor;
  final String? logoUrl;

  /// `tariff | api | none`
  final String estimateKind;
  final String? tariffId;

  /// `none | url | template`
  final String handoffKind;

  /// True when the API can build a prefilled deep link for this provider.
  final bool hasTemplate;
  final String? web;
  final String? appIos;
  final String? appAndroid;
  final String? scheme;
  final bool enabled;
  final int order;

  bool get isTaxi => kind == 'taxi';
  bool get hasEstimate => estimateKind != 'none';

  factory OnDemandProvider.fromJson(Map<String, dynamic> j) {
    final est = j['estimate'] is Map ? Map<String, dynamic>.from(j['estimate'] as Map) : const <String, dynamic>{};
    final ho = j['handoff'] is Map ? Map<String, dynamic>.from(j['handoff'] as Map) : const <String, dynamic>{};
    final apps = ho['apps'] is Map ? Map<String, dynamic>.from(ho['apps'] as Map) : const <String, dynamic>{};
    final template = ho['template']?.toString();
    return OnDemandProvider(
      id: j['id'].toString(),
      name: j['name']?.toString() ?? j['id'].toString(),
      kind: j['kind']?.toString() ?? 'ridehail',
      color: j['color']?.toString() ?? '#455A64',
      textColor: j['textColor']?.toString(),
      logoUrl: j['logoUrl']?.toString(),
      estimateKind: est['kind']?.toString() ?? 'none',
      tariffId: est['tariffId']?.toString(),
      handoffKind: ho['kind']?.toString() ?? 'none',
      hasTemplate: asBool(ho['hasTemplate'], fallback: template != null && template.isNotEmpty),
      web: ho['web']?.toString(),
      appIos: apps['ios']?.toString(),
      appAndroid: apps['android']?.toString(),
      scheme: ho['scheme']?.toString(),
      enabled: asBool(j['enabled'], fallback: true),
      order: asInt(j['order']) ?? 0,
    );
  }
}

class TariffSurcharge {
  const TariffSurcharge({required this.id, required this.label, required this.amount});
  final String id;
  final String label;
  final num amount;

  factory TariffSurcharge.fromJson(Map<String, dynamic> j) => TariffSurcharge(
        id: j['id'].toString(),
        label: j['label']?.toString() ?? j['id'].toString(),
        amount: (j['amount'] as num?) ?? 0,
      );
}

/// A regulated taxi tariff (flag fall + unit price + minimum + surcharges).
class TaxiTariff {
  const TaxiTariff({
    required this.id,
    required this.name,
    this.currency = 'COP',
    required this.flagFall,
    required this.unitPrice,
    this.unitMeters = 100,
    this.unitSeconds = 30,
    this.minimumFare = 0,
    this.surcharges = const [],
    this.sourceLabel,
    this.sourceUrl,
    this.validFrom,
    this.note,
  });
  final String id;
  final String name;
  final String currency;
  final num flagFall;
  final num unitPrice;
  final int unitMeters;
  final int unitSeconds;
  final num minimumFare;
  final List<TariffSurcharge> surcharges;
  final String? sourceLabel;
  final String? sourceUrl;
  final String? validFrom;
  final String? note;

  TariffSurcharge? surcharge(String id) => surcharges.where((s) => s.id == id).firstOrNull;

  factory TaxiTariff.fromJson(Map<String, dynamic> j) {
    final src = j['source'] is Map ? Map<String, dynamic>.from(j['source'] as Map) : const <String, dynamic>{};
    return TaxiTariff(
      id: j['id'].toString(),
      name: j['name']?.toString() ?? j['id'].toString(),
      currency: j['currency']?.toString() ?? 'COP',
      flagFall: (j['flagFall'] as num?) ?? 0,
      unitPrice: (j['unitPrice'] as num?) ?? 0,
      unitMeters: asInt(j['unitMeters']) ?? 100,
      unitSeconds: asInt(j['unitSeconds']) ?? 30,
      minimumFare: (j['minimumFare'] as num?) ?? 0,
      surcharges: asList(j['surcharges'], TariffSurcharge.fromJson),
      sourceLabel: src['label']?.toString(),
      sourceUrl: src['url']?.toString(),
      validFrom: j['validFrom']?.toString(),
      note: j['note']?.toString(),
    );
  }
}

class OnDemandPolicy {
  const OnDemandPolicy({
    this.maxDirectDistanceKm = 40,
    this.firstLastMile = true,
    this.maxFeederKm = 8,
    this.showWhenTransitFaster = true,
  });
  final num maxDirectDistanceKm;
  final bool firstLastMile;
  final num maxFeederKm;
  final bool showWhenTransitFaster;

  factory OnDemandPolicy.fromJson(Map<String, dynamic>? j) => j == null
      ? const OnDemandPolicy()
      : OnDemandPolicy(
          maxDirectDistanceKm: (j['maxDirectDistanceKm'] as num?) ?? 40,
          firstLastMile: asBool(j['firstLastMile'], fallback: true),
          maxFeederKm: (j['maxFeederKm'] as num?) ?? 8,
          showWhenTransitFaster: asBool(j['showWhenTransitFaster'], fallback: true),
        );
}

/// Price estimate of an on-demand ride (`leg.onDemand.providers[].price`,
/// `/ondemand/estimate`). `amount` is the point estimate, `min/max` the band.
class OnDemandPrice {
  const OnDemandPrice({
    required this.amount,
    this.min,
    this.max,
    required this.currency,
    this.estimated = true,
    this.breakdown = const [],
    this.surchargesApplied = const [],
  });
  final num amount;
  final num? min;
  final num? max;
  final String currency;
  final bool estimated;
  final List<TariffSurcharge> breakdown;
  final List<String> surchargesApplied;

  bool get hasRange => min != null && max != null && min != max;

  factory OnDemandPrice.fromJson(Map<String, dynamic> j) => OnDemandPrice(
        amount: (j['amount'] as num?) ?? (j['min'] as num?) ?? 0,
        min: j['min'] as num?,
        max: j['max'] as num?,
        currency: j['currency']?.toString() ?? 'COP',
        estimated: asBool(j['estimated'], fallback: true),
        breakdown: asList(j['breakdown'], (m) => TariffSurcharge(
              id: m['id']?.toString() ?? m['label']?.toString() ?? '',
              label: m['label']?.toString() ?? '',
              amount: (m['amount'] as num?) ?? 0,
            )),
        surchargesApplied: asStrings(j['surchargesApplied']),
      );
}

/// One provider option attached to a CAR leg or an estimate response.
class OnDemandOption {
  const OnDemandOption({
    required this.providerId,
    required this.name,
    this.color = '#455A64',
    this.kind,
    this.price,
    this.waitSeconds,
    this.handoffUrl,
    this.source = 'none',
  });
  final String providerId;
  final String name;
  final String color;

  /// `taxi | ridehail`, when the API sends it (estimate responses).
  final String? kind;
  final OnDemandPrice? price;
  final int? waitSeconds;

  /// API URL that builds the provider deep link server-side (credentials never
  /// reach the app). Append `platform=ios|android` before opening.
  final String? handoffUrl;

  /// `tariff | api | none`
  final String source;

  bool get hasPrice => price != null;

  factory OnDemandOption.fromJson(Map<String, dynamic> j) => OnDemandOption(
        providerId: j['providerId']?.toString() ?? j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? j['providerId']?.toString() ?? '',
        color: j['color']?.toString() ?? '#455A64',
        kind: j['kind']?.toString(),
        price: j['price'] is Map ? OnDemandPrice.fromJson(Map<String, dynamic>.from(j['price'] as Map)) : null,
        waitSeconds: asInt(j['waitSeconds']),
        handoffUrl: j['handoffUrl']?.toString(),
        source: j['source']?.toString() ?? 'none',
      );
}

/// `leg.onDemand` — the ride options for a CAR leg.
class LegOnDemand {
  const LegOnDemand({this.kind = 'taxi', this.providers = const [], this.recommendedProviderId});
  final String kind;
  final List<OnDemandOption> providers;
  final String? recommendedProviderId;

  OnDemandOption? get recommended =>
      providers.where((p) => p.providerId == recommendedProviderId).firstOrNull ?? providers.firstOrNull;

  /// `taxi | ridehail` for the chip: the recommended option's own kind when the
  /// API sends it, else the leg kind.
  String get displayKind => recommended?.kind ?? kind;

  /// The best estimate to show on cards: the recommended provider's price,
  /// else the cheapest priced option.
  OnDemandPrice? get displayPrice {
    final r = recommended?.price;
    if (r != null) return r;
    final priced = providers.where((p) => p.price != null).toList()
      ..sort((a, b) => a.price!.amount.compareTo(b.price!.amount));
    return priced.firstOrNull?.price;
  }

  factory LegOnDemand.fromJson(Map<String, dynamic> j) => LegOnDemand(
        kind: j['kind']?.toString() ?? 'taxi',
        providers: asList(j['providers'], OnDemandOption.fromJson),
        recommendedProviderId: j['recommendedProviderId']?.toString(),
      );
}

/// `/ondemand/estimate` envelope.
class OnDemandEstimate {
  const OnDemandEstimate({this.distanceMeters, this.durationSeconds, this.geometry, this.estimates = const []});
  final int? distanceMeters;
  final int? durationSeconds;
  final Geometry? geometry;
  final List<OnDemandOption> estimates;

  factory OnDemandEstimate.fromJson(Map<String, dynamic> j) {
    final r = j['route'] is Map ? Map<String, dynamic>.from(j['route'] as Map) : const <String, dynamic>{};
    return OnDemandEstimate(
      distanceMeters: asInt(r['distanceMeters']),
      durationSeconds: asInt(r['durationSeconds']),
      geometry: r['geometry'] is Map ? Geometry.fromJson(Map<String, dynamic>.from(r['geometry'] as Map)) : null,
      estimates: asList(j['estimates'], OnDemandOption.fromJson),
    );
  }
}

/// `/ondemand/handoff` response: the provider URL plus a store/web fallback.
class OnDemandHandoff {
  const OnDemandHandoff({required this.url, this.fallback, this.provider});
  final String url;
  final String? fallback;
  final OnDemandProvider? provider;

  factory OnDemandHandoff.fromJson(Map<String, dynamic> j) => OnDemandHandoff(
        url: j['url']?.toString() ?? '',
        fallback: j['fallback']?.toString(),
        provider: j['provider'] is Map ? OnDemandProvider.fromJson(Map<String, dynamic>.from(j['provider'] as Map)) : null,
      );
}

/// `health.ondemand`.
class OnDemandHealth {
  const OnDemandHealth({this.providers = 0, this.tariffs = 0, this.routerCar = true});
  final int providers;
  final int tariffs;
  final bool routerCar;

  factory OnDemandHealth.fromJson(Map<String, dynamic>? j) => j == null
      ? const OnDemandHealth()
      : OnDemandHealth(
          providers: asInt(j['providers']) ?? 0,
          tariffs: asInt(j['tariffs']) ?? 0,
          routerCar: asBool(j['routerCar'], fallback: true),
        );
}
