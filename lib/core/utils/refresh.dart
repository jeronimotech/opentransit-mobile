/// How often a board or an arrivals list re-reads itself.
///
/// Saver mode (TransMilenio, 1.15) triples it: a board that refreshes every minute instead of every
/// twenty seconds is still a useful board, and it is three times fewer requests and three times
/// less radio. The clamp is the contract's: never under five seconds, never over five minutes, so
/// neither a city's config nor the multiplier can produce a pathological interval.
Duration refreshInterval(int? citySeconds, {bool saver = false}) {
  final base = (citySeconds ?? 20).clamp(5, 300);
  return Duration(seconds: (base * (saver ? 3 : 1)).clamp(5, 300));
}
