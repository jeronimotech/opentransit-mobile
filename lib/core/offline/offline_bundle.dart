import 'dart:convert';

import '../models/models.dart';

/// A city's whole timetable, on disk, read one stop at a time.
///
/// The file is NDJSON: a header line — stops, routes, headsigns, calendar — then one line per stop
/// that anything calls at. Only the header is held in memory. The departures are not: expanded into
/// objects they are about 160 MB for Lisboa and 81 MB for Bogotá, which gets the app killed, so a
/// stop's line is read and parsed when a rider actually looks at that stop.
///
/// Nothing here touches the network. This is what the app has when it has nothing.
class OfflineHeader {
  const OfflineHeader({
    required this.formatVersion,
    required this.city,
    required this.routes,
    required this.headsigns,
    required this.services,
    required this.exceptions,
    required this.stops,
    required this.stopIndexById,
    this.feedVersion,
    this.builtAt,
    this.departures,
  });

  final int formatVersion;
  final String city;
  final String? feedVersion;
  final DateTime? builtAt;

  /// How many departures the builder put in. Shown so a rider can see the download did something,
  /// and so a suspiciously empty bundle is visible rather than silent.
  final int? departures;

  final List<OfflineRoute> routes;
  final List<String> headsigns;
  final List<OfflineService> services;

  /// serviceIndex -> yyyymmdd -> GTFS exception type (1 added, 2 removed).
  final Map<int, Map<String, int>> exceptions;

  final List<Stop> stops;
  final Map<String, int> stopIndexById;

  static OfflineHeader parse(String line) {
    final j = jsonDecode(line) as Map<String, dynamic>;
    final stops = <Stop>[];
    final byId = <String, int>{};
    for (final (i, raw) in (j['stops'] as List).indexed) {
      final s = raw as Map<String, dynamic>;
      final id = s['id'].toString();
      byId[id] = i;
      stops.add(Stop(
        id: id,
        name: (s['name'] ?? '').toString(),
        position: LatLng((s['lat'] as num).toDouble(), (s['lon'] as num).toDouble()),
        code: s['code']?.toString(),
        locationType: (s['type'] as num?)?.toInt() == 1 ? 'station' : 'stop',
        parentStationId: s['parent']?.toString(),
      ));
    }
    final exceptions = <int, Map<String, int>>{};
    for (final raw in (j['serviceExceptions'] as List? ?? const [])) {
      final e = raw as List;
      final idx = (e[0] as num).toInt();
      (exceptions[idx] ??= {})[e[1].toString()] = (e[2] as num).toInt();
    }
    return OfflineHeader(
      formatVersion: (j['v'] as num?)?.toInt() ?? 0,
      city: (j['city'] ?? '').toString(),
      feedVersion: j['feedVersion']?.toString(),
      builtAt: DateTime.tryParse(j['builtAt']?.toString() ?? ''),
      departures: ((j['stats'] as Map?)?['departures'] as num?)?.toInt(),
      routes: [
        for (final raw in (j['routes'] as List? ?? const []))
          OfflineRoute.parse(raw as Map<String, dynamic>),
      ],
      headsigns: [for (final h in (j['headsigns'] as List? ?? const [])) h.toString()],
      services: [
        for (final raw in (j['services'] as List? ?? const []))
          OfflineService.parse(raw as Map<String, dynamic>),
      ],
      exceptions: exceptions,
      stops: stops,
      stopIndexById: byId,
    );
  }

  /// Which services run on [day], by the same rule the builder applies.
  ///
  /// An explicit exception beats the weekday pattern in both directions, which is how a feed says
  /// "this Monday is a holiday" and how Roma and Lisboa say everything — neither ships a
  /// calendar.txt at all, so for them every service is exceptions only.
  Set<int> activeServices(DateTime day) {
    final ymd = '${day.year.toString().padLeft(4, '0')}'
        '${day.month.toString().padLeft(2, '0')}'
        '${day.day.toString().padLeft(2, '0')}';
    final out = <int>{};
    for (final s in services) {
      final kind = exceptions[s.index]?[ymd];
      if (kind == 2) continue;
      if (kind == 1) {
        out.add(s.index);
        continue;
      }
      final from = s.from, to = s.to;
      if (from == null || to == null) continue;
      // DateTime.weekday is 1 = Monday, and the array is Monday-first, as GTFS writes it.
      if (from.compareTo(ymd) <= 0 && ymd.compareTo(to) <= 0 && s.days[day.weekday - 1]) {
        out.add(s.index);
      }
    }
    return out;
  }
}

class OfflineRoute {
  const OfflineRoute({
    required this.id,
    this.short,
    this.long,
    this.color,
    this.textColor,
    this.type = 3,
    this.component,
  });
  final String id;
  final String? short;
  final String? long;
  final String? color;
  final String? textColor;
  final int type;

  /// trunk | feeder | dual | zonal | cable | …, as the city's own config defines it.
  ///
  /// The app colours and ices routes by component rather than by the GTFS colour, so without this
  /// every offline chip fell back to a generic grey and a downloaded board looked like a different
  /// app from the one online. Null for a bundle built before the builder carried it.
  final Component? component;

  static OfflineRoute parse(Map<String, dynamic> j) => OfflineRoute(
        id: j['id'].toString(),
        short: j['short']?.toString(),
        long: j['long']?.toString(),
        color: j['color']?.toString(),
        textColor: j['text']?.toString(),
        type: (j['type'] as num?)?.toInt() ?? 3,
        component: Component.parse(j['component']),
      );

  RouteRef toRef(String cityId) => RouteRef(
        id: '$cityId:$id',
        shortName: short ?? id,
        longName: long ?? short ?? id,
        color: color ?? '#607D8B',
        textColor: textColor ?? '#FFFFFF',
        mode: modeOf(type),
        component: component,
        // The bundle carries no agency: a board shows the route, and the operator behind it is not
        // something a rider offline can be told anything useful about.
        agencyId: '',
      );

  /// GTFS `route_type` -> the app's mode. Only the original seven plus the common extended values
  /// a feed is likely to use; anything else is a bus, which is what an unknown surface vehicle is
  /// in every one of our cities.
  static TravelMode modeOf(int routeType) => switch (routeType) {
        0 || 900 => TravelMode.tram,
        1 || 400 || 401 || 402 => TravelMode.subway,
        2 || 100 || 101 || 102 || 106 => TravelMode.rail,
        3 || 700 || 702 || 704 || 715 || 800 => TravelMode.bus,
        4 || 1000 || 1200 => TravelMode.ferry,
        5 || 6 || 1300 || 1301 => TravelMode.cableCar,
        7 || 1400 => TravelMode.cableCar,
        _ => TravelMode.bus,
      };
}

class OfflineService {
  const OfflineService({required this.index, required this.id, required this.days, this.from, this.to});
  final int index;
  final String id;

  /// Monday-first, as GTFS writes it.
  final List<bool> days;

  /// `yyyymmdd`, or null for a service with no calendar.txt row — which runs only on the dates
  /// calendar_dates.txt adds, and is a complete GTFS calendar rather than a gap.
  final String? from;
  final String? to;

  static OfflineService parse(Map<String, dynamic> j) => OfflineService(
        index: (j['idx'] as num).toInt(),
        id: j['id'].toString(),
        days: [for (final d in (j['days'] as List)) (d as num).toInt() == 1],
        from: (j['from']?.toString().isEmpty ?? true) ? null : j['from'].toString(),
        to: (j['to']?.toString().isEmpty ?? true) ? null : j['to'].toString(),
      );
}

/// One scheduled departure, read from the bundle. Never realtime: offline is exactly the state in
/// which nothing is live, and the board says so.
class OfflineDeparture {
  const OfflineDeparture({
    required this.minutesSinceServiceMidnight,
    required this.time,
    required this.route,
    required this.headsign,
    required this.serviceIndex,
  });

  /// Minutes since the service day's midnight. May exceed 1440: `25:10` is ten past one on a
  /// service day that began the previous morning, and folding it would sort the night bus to dawn.
  final int minutesSinceServiceMidnight;

  /// The wall-clock instant, already resolved against the service day this departure belongs to.
  final DateTime time;
  final OfflineRoute route;
  final String headsign;
  final int serviceIndex;
}


/// Turn one stop's line into departures on a given service day.
///
/// Pure, so the whole calendar-and-delta story is testable without a file. The line is
/// `{"s":<stopIndex>,"g":[[routeIdx, headsignIdx, serviceIdx, [first, gap, gap, …]], …]}`.
///
/// [serviceDay] is the local date whose timetable this is, not "today": a departure at `25:10`
/// belongs to the service day that began the previous morning, so a board drawn just after midnight
/// has to ask for yesterday's day as well as today's and merge. Keeping that decision out here is
/// why this function takes a day instead of reading the clock.
List<OfflineDeparture> decodeStopLine(
  String line,
  OfflineHeader header, {
  required DateTime serviceDay,
  Set<int>? onlyServices,
}) {
  final j = jsonDecode(line) as Map<String, dynamic>;
  final midnight = DateTime(serviceDay.year, serviceDay.month, serviceDay.day);
  final out = <OfflineDeparture>[];
  for (final raw in (j['g'] as List? ?? const [])) {
    final g = raw as List;
    final routeIdx = (g[0] as num).toInt();
    final headIdx = (g[1] as num).toInt();
    final svcIdx = (g[2] as num).toInt();
    if (onlyServices != null && !onlyServices.contains(svcIdx)) continue;
    if (routeIdx < 0 || routeIdx >= header.routes.length) continue;
    final route = header.routes[routeIdx];
    final headsign = headIdx >= 0 && headIdx < header.headsigns.length
        ? header.headsigns[headIdx]
        : '';
    var minutes = 0;
    for (final (i, d) in (g[3] as List).indexed) {
      final delta = (d as num).toInt();
      minutes = i == 0 ? delta : minutes + delta;
      out.add(OfflineDeparture(
        minutesSinceServiceMidnight: minutes,
        // Adding minutes to local midnight, not to a UTC instant: a service day that crosses a
        // DST change is still the day the agency published, and `DateTime.add` on a local
        // DateTime keeps the wall clock the timetable promised.
        time: midnight.add(Duration(minutes: minutes)),
        route: route,
        headsign: headsign,
        serviceIndex: svcIdx,
      ));
    }
  }
  out.sort((a, b) => a.minutesSinceServiceMidnight.compareTo(b.minutesSinceServiceMidnight));
  return out;
}
