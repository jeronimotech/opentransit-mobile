import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'offline_bundle.dart';

/// What is on disk for one city, and how to get it there.
///
/// Three files per city, under the app's documents directory:
///
/// * `<city>.ndjson`  — the decompressed bundle. Never read whole.
/// * `<city>.idx`     — stop index -> byte offset and length of that stop's line.
/// * `<city>.meta`    — what was installed: format version, feed version, byte size, when.
///
/// The index is built here rather than shipped because it is offsets into the *decompressed* file,
/// which only exists after installing, and because computing it costs one pass we are already
/// making.
class OfflineStore {
  OfflineStore({Dio? dio, Directory? directory}) : _dio = dio ?? Dio(), _dir = directory;

  final Dio _dio;
  Directory? _dir;

  Future<Directory> _root() async {
    final d = _dir ??= await getApplicationDocumentsDirectory();
    final sub = Directory('${d.path}/offline');
    if (!await sub.exists()) await sub.create(recursive: true);
    return sub;
  }

  Future<File> _file(String city, String ext) async => File('${(await _root()).path}/$city.$ext');

  /// What is installed for [city], or null when nothing is.
  Future<OfflineMeta?> meta(String city) async {
    final f = await _file(city, 'meta');
    if (!await f.exists()) return null;
    try {
      return OfflineMeta.parse(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
    } on Object {
      // A meta file we cannot read is a half-finished or corrupted install. Treat it as absent so
      // the rider is offered a download rather than shown a timetable we cannot vouch for.
      return null;
    }
  }

  /// Download, decompress and index a bundle, reporting progress from 0 to 1.
  ///
  /// Everything is written beside the real names and moved into place at the end, so an interrupted
  /// install leaves the previous bundle working rather than a half-written one pretending to be a
  /// timetable. [cancel] aborts the download and cleans up.
  Future<OfflineMeta> install(
    String city, {
    required String url,
    required int expectedBytes,
    void Function(double progress)? onProgress,
    CancelToken? cancel,
  }) async {
    final root = await _root();
    final gz = File('${root.path}/$city.ndjson.gz.part');
    try {
      // Download is the long part, so it owns most of the progress bar. The decompress-and-index
      // pass is quick but not free on a big city, and a bar that sticks at 100 % while the app
      // appears to hang is worse than one that admits there is a second stage.
      await _dio.download(url, gz.path, cancelToken: cancel,
          onReceiveProgress: (got, total) {
        final denom = total > 0 ? total : expectedBytes;
        if (denom > 0 && onProgress != null) onProgress((got / denom).clamp(0.0, 0.9));
      });
      return await installFromFile(city, gz, onProgress: onProgress);
    } finally {
      if (await gz.exists()) await gz.delete();
    }
  }

  /// Install from a gzipped bundle already on disk.
  ///
  /// Separate from [install] so everything except the HTTP request is testable, and so a bundle
  /// that arrived some other way — sideloaded, or bundled with a build for a launch city — can be
  /// installed by the same code that validates and indexes a downloaded one.
  Future<OfflineMeta> installFromFile(
    String city,
    File gz, {
    void Function(double progress)? onProgress,
  }) async {
    final root = await _root();
    final nd = File('${root.path}/$city.ndjson.part');
    final idx = File('${root.path}/$city.idx.part');
    var promoted = false;
    try {
      final index = await _decompressAndIndex(gz, nd, idx);
      final header = OfflineHeader.parse(await _firstLine(nd));
      if (header.formatVersion != 1) {
        throw OfflineInstallException(
            'bundle format ${header.formatVersion} is newer than this app understands');
      }
      if (index.isEmpty) {
        // A bundle with no stop lines installs and validates and shows nothing. The builder refuses
        // to publish one; refuse to install one too, in case an older asset is still pointed at.
        throw const OfflineInstallException('bundle contains no departures');
      }
      if (header.city != city) {
        // Installing Toronto's timetable as Bogotá's would produce a board of plausible times for
        // stops that do not exist here, which is worse than no board.
        throw OfflineInstallException("bundle is for '${header.city}', not '$city'");
      }

      final m = OfflineMeta(
        city: city,
        formatVersion: header.formatVersion,
        feedVersion: header.feedVersion,
        departures: header.departures,
        stops: index.length,
        bytes: await nd.length(),
        installedAt: DateTime.now(),
        builtAt: header.builtAt,
      );
      // Last: until both files are in place the previous bundle is still the installed one, so an
      // interrupted install leaves a working timetable rather than a half-written one.
      await nd.rename('${root.path}/$city.ndjson');
      await idx.rename('${root.path}/$city.idx');
      promoted = true;
      await (await _file(city, 'meta')).writeAsString(jsonEncode(m.toJson()));
      onProgress?.call(1.0);
      return m;
    } finally {
      if (!promoted) {
        for (final f in [nd, idx]) {
          if (await f.exists()) await f.delete();
        }
      }
    }
  }

  /// Stream the gzip out to a plain file, recording where each stop's line starts.
  ///
  /// Streamed rather than read whole because the decompressed file is 14 MB for Toronto and 58 MB
  /// for Lisboa, and holding either as one string is the memory problem this format exists to
  /// avoid.
  Future<Map<int, List<int>>> _decompressAndIndex(File gz, File nd, File idx) async {
    final index = <int, List<int>>{};
    final sink = nd.openWrite();
    var offset = 0;
    var lineNo = 0;
    try {
      final lines = gz
          .openRead()
          .transform(gzip.decoder)
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        final bytes = utf8.encode(line);
        sink.add(bytes);
        sink.add(const [10]);
        if (lineNo > 0) {
          // Only the stop index is needed, so read it without parsing the whole line: the line
          // starts `{"s":<n>,` and the departures after it are the expensive part.
          final s = _stopIndexOf(line);
          if (s != null) index[s] = [offset, bytes.length];
        }
        offset += bytes.length + 1;
        lineNo++;
      }
    } finally {
      await sink.close();
    }
    await idx.writeAsString(jsonEncode({
      for (final e in index.entries) e.key.toString(): e.value,
    }));
    return index;
  }

  /// `{"s":123,…` -> 123, without decoding the rest of the line.
  static int? _stopIndexOf(String line) {
    const prefix = '{"s":';
    if (!line.startsWith(prefix)) return null;
    final comma = line.indexOf(',', prefix.length);
    if (comma < 0) return null;
    return int.tryParse(line.substring(prefix.length, comma));
  }

  Future<String> _firstLine(File f) async {
    final lines = f.openRead().transform(utf8.decoder).transform(const LineSplitter());
    await for (final l in lines) {
      return l;
    }
    throw const OfflineInstallException('bundle is empty');
  }

  /// Open an installed bundle for reading. Null when nothing is installed.
  Future<InstalledBundle?> open(String city) async {
    final m = await meta(city);
    if (m == null) return null;
    final nd = await _file(city, 'ndjson');
    final idx = await _file(city, 'idx');
    if (!await nd.exists() || !await idx.exists()) return null;
    try {
      final raw = jsonDecode(await idx.readAsString()) as Map<String, dynamic>;
      final index = <int, List<int>>{
        for (final e in raw.entries)
          int.parse(e.key): [for (final v in e.value as List) (v as num).toInt()],
      };
      final header = OfflineHeader.parse(await _firstLine(nd));
      return InstalledBundle(meta: m, header: header, file: nd, lineIndex: index);
    } on Object {
      return null;
    }
  }

  Future<void> remove(String city) async {
    for (final ext in ['ndjson', 'idx', 'meta']) {
      final f = await _file(city, ext);
      if (await f.exists()) await f.delete();
    }
  }

  /// Total bytes this city occupies, for a settings screen that should not have to guess.
  Future<int> bytesOnDisk(String city) async {
    var total = 0;
    for (final ext in ['ndjson', 'idx', 'meta']) {
      final f = await _file(city, ext);
      if (await f.exists()) total += await f.length();
    }
    return total;
  }
}

/// An installed bundle, ready to answer one stop at a time.
class InstalledBundle {
  const InstalledBundle({
    required this.meta,
    required this.header,
    required this.file,
    required this.lineIndex,
  });

  final OfflineMeta meta;
  final OfflineHeader header;
  final File file;

  /// stop index -> [byte offset, byte length] of its line.
  final Map<int, List<int>> lineIndex;

  /// The scheduled departures at [stopId] from [at] onwards.
  ///
  /// Reads both today's and yesterday's service day. Just after midnight the useful departures are
  /// the tail of yesterday's timetable — a 25:10 night bus is yesterday's service — and a board
  /// that only asked for today would be empty at exactly the hour someone is waiting in the dark.
  Future<List<OfflineDeparture>> departures(
    String stopId, {
    required DateTime at,
    int limit = 10,
    /// How far ahead counts as "next". Without it a stop whose only remaining service is a night
    /// bus nineteen hours away would show it as the next departure, which is true and useless.
    /// Wider than the API's default hour, because offline there is nothing else to fall back to.
    Duration within = const Duration(hours: 3),
  }) async {
    final si = header.stopIndexById[stopId];
    if (si == null) return const [];
    final span = lineIndex[si];
    if (span == null) return const [];

    final line = await _readLine(span[0], span[1]);
    if (line == null) return const [];

    final today = DateTime(at.year, at.month, at.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final out = <OfflineDeparture>[
      for (final day in [yesterday, today])
        ...decodeStopLine(line, header, serviceDay: day, onlyServices: header.activeServices(day)),
    ];
    final until = at.add(within);
    final upcoming = out
        .where((d) => !d.time.isBefore(at) && !d.time.isAfter(until))
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    return upcoming.take(limit).toList(growable: false);
  }

  Future<String?> _readLine(int offset, int length) async {
    final raf = await file.open();
    try {
      await raf.setPosition(offset);
      return utf8.decode(await raf.read(length));
    } on Object {
      return null;
    } finally {
      await raf.close();
    }
  }
}

class OfflineMeta {
  const OfflineMeta({
    required this.city,
    required this.formatVersion,
    required this.stops,
    required this.bytes,
    required this.installedAt,
    this.feedVersion,
    this.departures,
    this.builtAt,
  });

  final String city;
  final int formatVersion;
  final String? feedVersion;
  final int? departures;
  final int stops;

  /// Size of the decompressed file, which is what the rider's phone actually gave up.
  final int bytes;
  final DateTime installedAt;

  /// When the feed this was built from was published, so a stale bundle can be spotted.
  final DateTime? builtAt;

  Map<String, dynamic> toJson() => {
        'city': city,
        'formatVersion': formatVersion,
        'feedVersion': ?feedVersion,
        'departures': ?departures,
        'stops': stops,
        'bytes': bytes,
        'installedAt': installedAt.toIso8601String(),
        'builtAt': ?builtAt?.toIso8601String(),
      };

  static OfflineMeta parse(Map<String, dynamic> j) => OfflineMeta(
        city: j['city'].toString(),
        formatVersion: (j['formatVersion'] as num).toInt(),
        feedVersion: j['feedVersion']?.toString(),
        departures: (j['departures'] as num?)?.toInt(),
        stops: (j['stops'] as num?)?.toInt() ?? 0,
        bytes: (j['bytes'] as num?)?.toInt() ?? 0,
        installedAt: DateTime.tryParse(j['installedAt']?.toString() ?? '') ?? DateTime.now(),
        builtAt: DateTime.tryParse(j['builtAt']?.toString() ?? ''),
      );
}

class OfflineInstallException implements Exception {
  const OfflineInstallException(this.message);
  final String message;
  @override
  String toString() => 'OfflineInstallException: $message';
}
