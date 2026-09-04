// Text clean-up for feed strings (headsigns, route long names).

final _separators = RegExp(r'\s*(\|\||\s-\s|–|—)\s*');
final _allCaps = RegExp(r'^[^a-z]*[A-ZÁÉÍÓÚÑ][^a-z]*$');
const _smallWords = {'de', 'del', 'la', 'las', 'el', 'los', 'y', 'a', 'en', 'al'};

/// Title-cases an ALL-CAPS segment (`PORTAL NORTE` → `Portal Norte`), leaving
/// short tokens like `T4` or `2-11` alone and mixed-case text untouched.
String titleCaseIfCaps(String s) {
  final t = s.trim();
  if (t.length < 4 || !_allCaps.hasMatch(t)) return t;
  final words = t.split(RegExp(r'\s+'));
  return [
    for (var i = 0; i < words.length; i++) _titleWord(words[i], first: i == 0),
  ].join(' ');
}

String _titleWord(String w, {required bool first}) {
  if (w.length <= 2 || RegExp(r'\d').hasMatch(w)) return w; // T4, 2-11, N°
  final lower = w.toLowerCase();
  if (!first && _smallWords.contains(lower)) return lower;
  return lower[0].toUpperCase() + lower.substring(1);
}

/// `"Andalucía || Portal Norte"` → `"Andalucía → Portal Norte"`;
/// `"P. SUR - PORTAL NORTE"` → `"P. Sur → Portal Norte"`. Empty/null → null.
String? cleanHeadsign(String? raw) {
  if (raw == null) return null;
  final parts = raw
      .split(_separators)
      .map((p) => titleCaseIfCaps(p.replaceAll(RegExp(r'\s+'), ' ')))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return null;
  return parts.join(' → ');
}
