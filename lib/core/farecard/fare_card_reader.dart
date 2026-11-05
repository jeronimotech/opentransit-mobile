// NFC I/O for fare cards: the thin shell around flutter_nfc_kit that runs the read-only
// APDU sequence and hands the raw responses to the pure parser in tullave.dart.
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';

import 'tullave.dart';

enum FareCardReadError { unavailable, disabled, timeout, notTullave, failed }

class FareCardException implements Exception {
  const FareCardException(this.reason, [this.detail]);
  final FareCardReadError reason;
  final Object? detail;
  @override
  String toString() => 'FareCardException($reason${detail == null ? '' : ': $detail'})';
}

enum CardNfcState { unsupported, disabled, ready }

abstract class FareCardReader {
  Future<CardNfcState> state();

  /// Poll for a tullave and read it. Throws [FareCardException] on any failure.
  Future<TullaveCard> readTullave();
}

class NfcFareCardReader implements FareCardReader {
  const NfcFareCardReader();

  @override
  Future<CardNfcState> state() async {
    try {
      return switch (await FlutterNfcKit.nfcAvailability) {
        NFCAvailability.available => CardNfcState.ready,
        NFCAvailability.disabled => CardNfcState.disabled,
        NFCAvailability.not_supported => CardNfcState.unsupported,
      };
    } catch (_) {
      return CardNfcState.unsupported;
    }
  }

  @override
  Future<TullaveCard> readTullave() async {
    final avail = await state();
    if (avail == CardNfcState.unsupported) throw const FareCardException(FareCardReadError.unavailable);
    if (avail == CardNfcState.disabled) throw const FareCardException(FareCardReadError.disabled);

    try {
      await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 20),
        iosAlertMessage: 'Acerca tu tullave',
        readIso15693: false,
      );
    } on Exception catch (e) {
      throw FareCardException(FareCardReadError.timeout, e);
    }

    try {
      Future<String> tx(String capdu) => FlutterNfcKit.transceive(capdu);
      final fci = await tx(TullaveApdu.selectAid);
      // A card that does not answer the tullave SELECT is some other NFC card in the field.
      if (!fci.toUpperCase().endsWith('9000')) {
        throw const FareCardException(FareCardReadError.notTullave);
      }
      final value = await tx(TullaveApdu.value);
      await tx(TullaveApdu.readBinary);
      await tx(TullaveApdu.selectEf);
      final records = <String>[];
      for (var i = 1; i <= TullaveApdu.recordCount; i++) {
        records.add(await tx(TullaveApdu.recordApdu(i)));
      }
      return parseTullave(fciHex: fci, valueHex: value, recordHex: records);
    } on FareCardException {
      rethrow;
    } on Exception catch (e) {
      throw FareCardException(FareCardReadError.failed, e);
    } finally {
      try {
        await FlutterNfcKit.finish(iosAlertMessage: 'Listo');
      } catch (_) {}
    }
  }
}
