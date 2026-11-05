/// tullave (Bogotá) fare-card reading — pure parsing, no NFC/Flutter imports.
///
/// Validated on real hardware 2026-11-05 (see REFERENCE-APPS.md §1-bis): the card answers
/// plain ISO 7816 with no authentication. We read, entirely on-device, the balance, the card
/// number and the last ten movements. Nothing here writes, credits or debits.
library;

/// Fare cards we can read on-device. The server plays no part (reading is pure NFC), so this is
/// a client capability, not city config — though the UI still honours a `fareCard` kill-switch
/// in city config on top of it.
enum FareCardType { tullave }

const Map<String, FareCardType> fareCardByCity = {'bogota': FareCardType.tullave};

FareCardType? fareCardFor(String cityId) => fareCardByCity[cityId];

/// The read-only APDU sequence. `recordApdu(n)` reads movement n (1..[recordCount]).
class TullaveApdu {
  static const selectAid = '00A4040007D4100000030001'; // SELECT by AID D4 10 00 00 03 00 01
  static const value = '904C000004'; // value counter -> balance
  static const readBinary = '00B0860042'; // unused on the cards seen so far
  static const selectEf = '00A40000024200'; // SELECT EF 0x4200 (carries the card number in its FCI)
  static const recordCount = 10;
  static String recordApdu(int n) => '00B2${n.toRadixString(16).padLeft(2, '0')}242E';
}

enum TullaveMovementKind { trip, topUp, topUpReversal, unknown }

class TullaveMovement {
  const TullaveMovement({
    required this.kind,
    required this.amountCop,
    required this.balanceAfterCop,
    required this.at,
    required this.sequence,
  });
  final TullaveMovementKind kind;
  final int amountCop;
  final int balanceAfterCop;
  final DateTime? at;
  final int sequence;
}

class TullaveCard {
  const TullaveCard({required this.number, required this.balanceCop, required this.movements});
  final String number;
  final int balanceCop;

  /// Newest first.
  final List<TullaveMovement> movements;
}

/// Assemble a card from the raw responses (as hex strings, status word allowed/stripped).
/// [fciHex] is the SELECT response, [valueHex] the value read, [recordHex] the ten records.
TullaveCard parseTullave({required String fciHex, required String valueHex, required List<String> recordHex}) {
  final movements = [for (final h in recordHex) ?parseMovement(h)];
  final balance = parseBalance(valueHex) ?? (movements.isNotEmpty ? movements.first.balanceAfterCop : 0);
  return TullaveCard(number: parseCardNumber(fciHex) ?? '', balanceCop: balance, movements: movements);
}

/// Card number: FCI bytes[8:16) read as 16 decimal digits (tullave numbers start "1010").
String? parseCardNumber(String fciHex) {
  final b = _bytes(_stripStatus(fciHex));
  if (b.length < 16) return null;
  final digits = b.sublist(8, 16).map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return digits;
}

/// Balance: first 4 bytes big-endian, in COP.
int? parseBalance(String valueHex) {
  final b = _bytes(_stripStatus(valueHex));
  if (b.length < 4) return null;
  return _be(b, 0, 4);
}

/// One movement record (46 bytes). Returns null for an empty/padding slot.
TullaveMovement? parseMovement(String recordHex) {
  final b = _bytes(_stripStatus(recordHex));
  if (b.length < 33) return null;
  final balance = _be(b, 2, 4);
  final amount = _be(b, 10, 4);
  if (b[0] == 0 && balance == 0 && amount == 0) return null; // empty slot
  return TullaveMovement(
    kind: switch (b[0]) {
      0x01 => TullaveMovementKind.trip,
      0x02 => TullaveMovementKind.topUp,
      0x04 => TullaveMovementKind.topUpReversal,
      _ => TullaveMovementKind.unknown,
    },
    amountCop: amount,
    balanceAfterCop: balance,
    sequence: _be(b, 6, 4),
    at: _bcdDateTime(b.sublist(26, 30), b.sublist(30, 33)),
  );
}

int _be(List<int> b, int start, int len) {
  var v = 0;
  for (var i = 0; i < len; i++) {
    v = (v << 8) | b[start + i];
  }
  return v;
}

/// Date is BCD YYYYMMDD (4 bytes), time is BCD HHMMSS (3 bytes). Null if the BCD is not valid.
DateTime? _bcdDateTime(List<int> date, List<int> time) {
  int? bcd(int x) {
    final hi = x >> 4, lo = x & 0x0F;
    if (hi > 9 || lo > 9) return null;
    return hi * 10 + lo;
  }

  final y1 = bcd(date[0]), y2 = bcd(date[1]), mo = bcd(date[2]), da = bcd(date[3]);
  final hh = bcd(time[0]), mm = bcd(time[1]), ss = bcd(time[2]);
  if ([y1, y2, mo, da, hh, mm, ss].any((v) => v == null)) return null;
  final year = y1! * 100 + y2!;
  if (mo! < 1 || mo > 12 || da! < 1 || da > 31 || hh! > 23 || mm! > 59 || ss! > 59) return null;
  try {
    return DateTime(year, mo, da, hh, mm, ss);
  } catch (_) {
    return null;
  }
}

String _stripStatus(String hex) {
  final h = hex.replaceAll(' ', '').toUpperCase();
  return (h.length >= 4 && h.endsWith('9000')) ? h.substring(0, h.length - 4) : h;
}

List<int> _bytes(String hex) {
  final h = hex.replaceAll(' ', '');
  return [for (var i = 0; i + 1 < h.length; i += 2) int.parse(h.substring(i, i + 2), radix: 16)];
}
