/// Compares dotted version strings (`1.2.3`, `1.2`, `1.2.3+45`).
/// Returns <0 when [a] < [b], 0 when equal, >0 when [a] > [b].
int compareVersions(String a, String b) {
  List<int> parts(String v) => v
      .split('+')
      .first
      .split('-')
      .first
      .split('.')
      .map((x) => int.tryParse(x.trim()) ?? 0)
      .toList();
  final pa = parts(a), pb = parts(b);
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

/// True when [current] is older than [minimum] (null/empty minimum = fine).
bool needsUpdate(String current, String? minimum) =>
    minimum != null && minimum.trim().isNotEmpty && compareVersions(current, minimum) < 0;
