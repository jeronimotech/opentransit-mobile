import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One live link this phone published.
///
/// The write key is what lets the app take the page down again, so it is kept here and nowhere
/// else — it never goes into the shared message.
class LiveShare {
  const LiveShare({
    required this.cityId,
    required this.token,
    required this.writeKey,
    required this.url,
    this.label,
    this.expiresAt,
    this.createdAt,
  });

  final String cityId;
  final String token;
  final String writeKey;
  final String url;
  final String? label;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  bool isExpiredAt(DateTime now) => expiresAt != null && !expiresAt!.isAfter(now);

  Map<String, dynamic> toJson() => {
        'cityId': cityId,
        'token': token,
        'writeKey': writeKey,
        'url': url,
        if (label != null) 'label': label,
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };

  static LiveShare? fromJson(Map<String, dynamic> j) {
    final token = j['token']?.toString();
    final key = j['writeKey']?.toString();
    if (token == null || token.isEmpty || key == null || key.isEmpty) return null;
    return LiveShare(
      cityId: j['cityId']?.toString() ?? '',
      token: token,
      writeKey: key,
      url: j['url']?.toString() ?? '',
      label: j['label']?.toString(),
      expiresAt: DateTime.tryParse(j['expiresAt']?.toString() ?? ''),
      createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
    );
  }
}

/// Every live link this phone has published and not yet taken down.
///
/// Asked for by TransMilenio against 1.16.0 (1.10): a rider could publish a live page and had no
/// way to stop it afterwards — the only button was inside the trip that created it, so closing the
/// app left the page up until it expired on its own.
///
/// Device-only, like favourites and scheduled trips. Expired entries are dropped on read rather
/// than kept as rows the rider cannot act on.
class LiveSharesRepository {
  LiveSharesRepository(this._prefs);
  final SharedPreferences _prefs;

  static const _key = 'liveShares';

  List<LiveShare> all({DateTime? now}) {
    final at = now ?? DateTime.now();
    final raw = _prefs.getStringList(_key) ?? const [];
    final out = <LiveShare>[];
    for (final line in raw) {
      try {
        final share = LiveShare.fromJson(Map<String, dynamic>.from(jsonDecode(line) as Map));
        if (share != null && !share.isExpiredAt(at)) out.add(share);
      } on Object {
        // A row we cannot read is a row we cannot revoke either; dropping it beats crashing the
        // sheet that exists to stop these links.
        continue;
      }
    }
    out.sort((a, b) => (b.createdAt ?? at).compareTo(a.createdAt ?? at));
    return out;
  }

  Future<void> add(LiveShare share) async {
    final kept = all().where((s) => s.token != share.token).toList();
    await _write([share, ...kept]);
  }

  Future<void> remove(String token) async =>
      _write(all().where((s) => s.token != token).toList());

  /// Drops entries that have expired on their own, so the list never shows a link that is already
  /// dead — called on read by the sheet.
  Future<void> prune({DateTime? now}) => _write(all(now: now));

  Future<void> _write(List<LiveShare> shares) =>
      _prefs.setStringList(_key, [for (final s in shares) jsonEncode(s.toJson())]);
}
