import 'package:intl/intl.dart';

import '../models/models.dart';

/// Estimates a fare from the city parameters when the API returned none.
///
/// Rule (mirrors the API): the first transit leg pays the base fare; each
/// further transit leg that boards within `transferWindowMinutes` of the first
/// boarding pays the transfer fare, up to `maxTransfers` such legs; beyond
/// that (or outside the window) a leg pays the base fare again.
Fare? estimateFare(Itinerary it, CityFares? fares) {
  if (fares == null) return null;
  final legs = it.legs.where((l) => l.transit).toList();
  if (legs.isEmpty) return null;
  num total = fares.base;
  final lines = <FareLine>[FareLine(label: 'base', amount: fares.base)];
  final firstBoard = legs.first.startTime;
  var transfers = 0;
  for (final l in legs.skip(1)) {
    final within = l.startTime.difference(firstBoard).inMinutes <= fares.transferWindowMinutes;
    if (within && transfers < fares.maxTransfers) {
      transfers++;
      total += fares.transfer;
      lines.add(FareLine(label: 'transfer', amount: fares.transfer));
    } else {
      total += fares.base;
      lines.add(FareLine(label: 'base', amount: fares.base));
    }
  }
  return Fare(amount: total, currency: fares.currency, estimated: true, breakdown: lines);
}

/// Fare to show for an itinerary: the API's, else a client estimate.
Fare? fareFor(Itinerary it, City? city) => it.fare ?? estimateFare(it, city?.fares);

/// `COP 3200` → `$ 3.200`, `USD 2.5` → `US$ 2,50` (locale aware).
String formatMoney(num amount, String currency, String locale) {
  final symbol = switch (currency.toUpperCase()) {
    'COP' => r'$',
    'USD' => r'US$',
    'EUR' => '€',
    'MXN' => r'MX$',
    'BRL' => r'R$',
    _ => currency.toUpperCase(),
  };
  final decimals = (currency.toUpperCase() == 'COP' || amount == amount.roundToDouble()) ? 0 : 2;
  // Symbol always leads (`$ 3.200`), whatever the locale's default placement.
  final f = NumberFormat.currency(locale: locale, symbol: '', decimalDigits: decimals);
  return '$symbol ${f.format(amount).trim()}';
}
