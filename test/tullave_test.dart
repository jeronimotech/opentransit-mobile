import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/farecard/tullave.dart';

// Real responses captured from a physical tullave on 2026-11-05 (see REFERENCE-APPS §1-bis).
const _fci = '6F31B02F01100108101000002074081700020741812012082700000000011100989680000100000000000000000000000000009000';
const _value = '0000396C9000';
const _records = [
  '012C0000396C0000002E000009600820020010000975003C03E82019111408081200000000000000000000000000009000',
  '022C000042CC0000002D0000271008200100100124530000316B20191114080747000000000000000000000000009000',
  '022C00001BBC0000002D0000138808200100100124530000316A20191114080734000000000000000000000000009000',
  '012C000008340000002C000009600820020010000974003DE85A20191022080258000000000000000000000000009000',
  '022C000011940000002A000003E8082001001001245300001BB620191022080241000000000000000000000000009000',
  '022C00000DAC0000002A000003E8082001001001245300001BB520191022080229000000000000000000000000009000',
  '022C000009C400000029000003E8082001001001245300001BB420191022080217000000000000000000000000009000',
  '012C000005DC00000028000009600820020010000975003A079D20190925081018000000000000000000000000009000',
  '022C00000F3C00000026000007D008200100100124530000060B20190925080958000000000000000000000000009000',
  '012C0000076C00000026000009600820020010000974003C950220190919083016000000000000000000000000009000',
];

void main() {
  test('balance parses to 14 700 COP (big-endian, status stripped)', () {
    expect(parseBalance(_value), 14700);
  });

  test('card number is the 16 digits from the FCI', () {
    expect(parseCardNumber(_fci), '1010000020740817');
  });

  test('newest movement: a 2 400 trip leaving 14 700, on 2026-era date fields', () {
    final m = parseMovement(_records.first)!;
    expect(m.kind, TullaveMovementKind.trip);
    expect(m.amountCop, 2400);
    expect(m.balanceAfterCop, 14700);
    expect(m.at, DateTime(2019, 11, 14, 8, 8, 12));
  });

  test('a recarga is tagged as top-up', () {
    final m = parseMovement(_records[1])!;
    expect(m.kind, TullaveMovementKind.topUp);
    expect(m.amountCop, 10000);
    expect(m.balanceAfterCop, 17100);
  });

  test('the whole card assembles and every movement reconciles to the peso', () {
    final c = parseTullave(fciHex: _fci, valueHex: _value, recordHex: _records);
    expect(c.number, '1010000020740817');
    expect(c.balanceCop, 14700);
    expect(c.movements.length, 10);
    // Walk oldest -> newest applying +topup / -trip; each must equal the stored "balance after".
    final chron = c.movements.reversed.toList();
    int? running;
    for (final m in chron) {
      final delta = switch (m.kind) {
        TullaveMovementKind.topUp => m.amountCop,
        TullaveMovementKind.trip => -m.amountCop,
        _ => 0,
      };
      final calc = running == null ? m.balanceAfterCop : running + delta;
      expect(calc, m.balanceAfterCop, reason: 'reconcile seq ${m.sequence}');
      running = m.balanceAfterCop;
    }
    expect(running, 14700);
  });

  test('an empty/padding record is skipped', () {
    expect(parseMovement('00' * 46 + '9000'), isNull);
  });

  test('capability: only Bogotá reads a card today', () {
    expect(fareCardFor('bogota'), FareCardType.tullave);
    expect(fareCardFor('toronto'), isNull);
  });

  test('record APDU is well-formed (READ RECORD n, Le=0x2E)', () {
    expect(TullaveApdu.recordApdu(1), '00B201242E');
    expect(TullaveApdu.recordApdu(10), '00B20a242E');
  });
}
