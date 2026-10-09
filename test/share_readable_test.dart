library;

/// Sharing a trip as something a person can read, and being able to stop a live link (1.10).
///
/// Before this, sharing sent a bare URL — useless to whoever reads it on a phone with no data —
/// and the only "stop sharing" button lived inside the trip that created the link.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
// Clock formatting asks intl for Spanish symbols, which a plain test has to load itself; inside the
// app the localisation delegates do it.
import 'package:intl/date_symbol_data_local.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/storage/live_shares.dart';
import 'package:opentransit_mobile/core/utils/itinerary_text.dart';
import 'package:opentransit_mobile/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/factories.dart';

final _nine = DateTime(2026, 10, 9, 9, 0);

Itinerary _trip() => itinerary(start: _nine, transfers: 1, legs: [
      leg(start: _nine, minutes: 6, toName: 'Portal Norte', distanceMeters: 450),
      leg(
        start: _nine.add(const Duration(minutes: 6)),
        minutes: 24,
        mode: TravelMode.bus,
        transit: true,
        route: routeRef(id: 'bogota:B74', shortName: 'B74'),
        fromName: 'Portal Norte',
        toName: 'Av Chile',
        headsign: 'Museo Nacional',
      ),
      leg(start: _nine.add(const Duration(minutes: 30)), minutes: 5, fromName: 'Av Chile', toName: 'Oficina',
          distanceMeters: 320),
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations es;
  setUpAll(() async {
    initializeDateFormatting('es');
    es = await AppLocalizations.delegate.load(const Locale('es'));
  });

  group('readable itinerary', () {
    test('the message carries the steps, not only a link', () {
      final text = itineraryAsText(_trip(), es, 'es', fromName: 'Casa', toName: 'Oficina',
          link: 'https://opentransit.tech/t/abc');
      expect(text, contains('Casa → Oficina'));
      // Which vehicle, where to get on, where to get off: the three things a link hides.
      expect(text, contains('B74'));
      expect(text, contains('Portal Norte'));
      expect(text, contains('Av Chile'));
      expect(text, contains('Museo Nacional'));
      expect(text, contains('https://opentransit.tech/t/abc'));
      // Numbered, because this gets read out loud over the phone.
      expect(text, contains('1. '));
      expect(text, contains('3. '));
    });

    test('a trip with no link is still a complete message', () {
      final text = itineraryAsText(_trip(), es, 'es');
      expect(text, isNot(contains('http')));
      expect(text.trim().endsWith('Oficina') || text.contains('Oficina'), isTrue);
    });

    test('the summary line says when it leaves, when it arrives and how many transfers', () {
      final text = itineraryAsText(_trip(), es, 'es').split('\n')[1];
      expect(text, contains('–'));
      expect(text, contains('transbordo'));
    });
  });

  group('live links', () {
    late SharedPreferences prefs;
    late LiveSharesRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repo = LiveSharesRepository(prefs);
    });

    LiveShare share(String token, {DateTime? expires, DateTime? created}) => LiveShare(
          cityId: 'bogota',
          token: token,
          writeKey: 'k-$token',
          url: 'https://opentransit.tech/t/$token',
          label: 'Oficina',
          expiresAt: expires,
          createdAt: created ?? _nine,
        );

    test('a published link is remembered with the key that can take it down', () async {
      await repo.add(share('a', expires: _nine.add(const Duration(hours: 2))));
      final all = repo.all(now: _nine);
      expect(all, hasLength(1));
      expect(all.single.writeKey, 'k-a');
    });

    test('stopping one removes it', () async {
      await repo.add(share('a'));
      await repo.add(share('b'));
      await repo.remove('a');
      expect(repo.all(now: _nine).map((s) => s.token), ['b']);
    });

    test('a link that expired on its own is not offered as stoppable', () async {
      await repo.add(share('old', expires: _nine.subtract(const Duration(minutes: 1))));
      expect(repo.all(now: _nine), isEmpty);
    });

    test('publishing the same token twice keeps one row', () async {
      await repo.add(share('a'));
      await repo.add(share('a'));
      expect(repo.all(now: _nine), hasLength(1));
    });

    test('the newest link comes first', () async {
      await repo.add(share('old', created: _nine.subtract(const Duration(hours: 1))));
      await repo.add(share('new', created: _nine));
      expect(repo.all(now: _nine).map((s) => s.token), ['new', 'old']);
    });

    test('a row written by an older build that cannot be read is dropped, not crashed on', () async {
      await prefs.setStringList('liveShares', ['not json', '{"token":"x"}']);
      // The second has no write key, so it could never be revoked anyway.
      expect(repo.all(now: _nine), isEmpty);
    });
  });
}
