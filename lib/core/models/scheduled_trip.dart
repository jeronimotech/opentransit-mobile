import 'common.dart';
import 'plan.dart';

/// A trip the rider wants to be reminded of: Casa → Trabajo every weekday to arrive by 8:00, or one
/// appointment tomorrow at 10:30. It lives on the device only — the server never learns a routine.
///
/// Three reminders follow from it (see `TripScheduler`): the evening before ("mañana sal a las 7:12"),
/// twenty minutes before leaving with live data, and at the moment to leave.
class ScheduledTrip {
  const ScheduledTrip({
    required this.id,
    required this.cityId,
    required this.from,
    required this.to,
    required this.hour,
    required this.minute,
    this.arriveBy = true,
    this.days = const {},
    this.date,
    this.enabled = true,
    this.modes = const ['TRANSIT', 'WALK'],
    this.onDemand = false,
    this.createdAt,
    this.lastPlan,
  });

  final String id;
  final String cityId;
  final Place from;
  final Place to;

  /// Local time of day the trip is pinned to: arrival (`arriveBy`) or departure.
  final int hour;
  final int minute;
  final bool arriveBy;

  /// Weekdays (`DateTime.monday`…`DateTime.sunday`) for a repeating trip; empty for a one-off.
  final Set<int> days;

  /// The day of a one-off trip (date part only); null for a repeating one.
  final DateTime? date;
  final bool enabled;
  final List<String> modes;
  final bool onDemand;
  final DateTime? createdAt;

  /// What the planner last said for the next occurrence, so the list and the reminders can speak
  /// without a network round trip.
  final ScheduledTripPlan? lastPlan;

  bool get repeats => days.isNotEmpty;
  bool get isWeekdays => days.length == 5 && !days.contains(DateTime.saturday) && !days.contains(DateTime.sunday);
  bool get isDaily => days.length == 7;

  /// The next date-time the trip is pinned to (arrival or departure), at or after [now]. Null once a
  /// one-off trip is in the past.
  DateTime? nextOccurrence(DateTime now) {
    if (date != null) {
      final at = DateTime(date!.year, date!.month, date!.day, hour, minute);
      return at.isAfter(now) ? at : null;
    }
    if (days.isEmpty) return null;
    for (var i = 0; i < 8; i++) {
      final day = DateTime(now.year, now.month, now.day + i);
      if (!days.contains(day.weekday)) continue;
      final at = DateTime(day.year, day.month, day.day, hour, minute);
      if (at.isAfter(now)) return at;
    }
    return null;
  }

  ScheduledTrip copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    bool? arriveBy,
    Set<int>? days,
    DateTime? date,
    bool clearDate = false,
    ScheduledTripPlan? lastPlan,
    bool clearPlan = false,
  }) =>
      ScheduledTrip(
        id: id,
        cityId: cityId,
        from: from,
        to: to,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        arriveBy: arriveBy ?? this.arriveBy,
        days: days ?? this.days,
        date: clearDate ? null : (date ?? this.date),
        enabled: enabled ?? this.enabled,
        modes: modes,
        onDemand: onDemand,
        createdAt: createdAt,
        lastPlan: clearPlan ? null : (lastPlan ?? this.lastPlan),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'cityId': cityId,
        'from': _placeJson(from),
        'to': _placeJson(to),
        'hour': hour,
        'minute': minute,
        'arriveBy': arriveBy,
        'days': days.toList()..sort(),
        if (date != null) 'date': '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}',
        'enabled': enabled,
        'modes': modes,
        'onDemand': onDemand,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (lastPlan != null) 'lastPlan': lastPlan!.toJson(),
      };

  static Map<String, dynamic> _placeJson(Place p) => {
        'name': p.name, 'lat': p.position.lat, 'lon': p.position.lon,
        if (p.stopId != null) 'stopId': p.stopId,
      };

  factory ScheduledTrip.fromJson(Map<String, dynamic> j) {
    final d = j['date']?.toString();
    return ScheduledTrip(
      id: j['id'].toString(),
      cityId: j['cityId'].toString(),
      from: Place.fromJson(Map<String, dynamic>.from(j['from'] as Map)),
      to: Place.fromJson(Map<String, dynamic>.from(j['to'] as Map)),
      hour: asInt(j['hour']) ?? 8,
      minute: asInt(j['minute']) ?? 0,
      arriveBy: j['arriveBy'] == null ? true : asBool(j['arriveBy']),
      days: {for (final x in (j['days'] as List? ?? const [])) if (asInt(x) != null) asInt(x)!},
      date: d == null ? null : DateTime.tryParse(d),
      enabled: j['enabled'] == null ? true : asBool(j['enabled']),
      modes: asStrings(j['modes']).isEmpty ? const ['TRANSIT', 'WALK'] : asStrings(j['modes']),
      onDemand: asBool(j['onDemand']),
      createdAt: parseTime(j['createdAt']),
      lastPlan: j['lastPlan'] is Map ? ScheduledTripPlan.fromJson(Map<String, dynamic>.from(j['lastPlan'] as Map)) : null,
    );
  }
}

/// The planner's answer for one occurrence: when to leave, when you get there, which routes.
class ScheduledTripPlan {
  const ScheduledTripPlan({
    required this.occurrence,
    required this.leaveAt,
    required this.arriveAt,
    required this.routes,
    required this.computedAt,
    this.realtime = false,
  });

  /// The pinned date-time this plan answers (arrival or departure).
  final DateTime occurrence;
  final DateTime leaveAt;
  final DateTime arriveAt;

  /// Short names of the transit routes, in order ("G30", "J23").
  final List<String> routes;
  final DateTime computedAt;
  final bool realtime;

  String get routesLabel => routes.join(' + ');

  Map<String, dynamic> toJson() => {
        'occurrence': occurrence.toIso8601String(),
        'leaveAt': leaveAt.toIso8601String(),
        'arriveAt': arriveAt.toIso8601String(),
        'routes': routes,
        'computedAt': computedAt.toIso8601String(),
        'realtime': realtime,
      };

  factory ScheduledTripPlan.fromJson(Map<String, dynamic> j) => ScheduledTripPlan(
        occurrence: DateTime.parse(j['occurrence'].toString()).toLocal(),
        leaveAt: DateTime.parse(j['leaveAt'].toString()).toLocal(),
        arriveAt: DateTime.parse(j['arriveAt'].toString()).toLocal(),
        routes: asStrings(j['routes']),
        computedAt: DateTime.parse(j['computedAt'].toString()).toLocal(),
        realtime: asBool(j['realtime']),
      );

  /// The itinerary to plan the day around: for "arrive by", the one that leaves latest and still gets
  /// there in time; for "depart at", the one that arrives first. Null when nothing fits.
  static ScheduledTripPlan? pick(List<Itinerary> its, {required DateTime occurrence, required bool arriveBy,
                                 required DateTime now, DateTime? notBefore}) {
    Iterable<Itinerary> ok = its;
    if (arriveBy) {
      ok = its.where((i) => !i.endTime.isAfter(occurrence));
    }
    // the live check asks "what do I do now": a departure already gone is not an answer
    if (notBefore != null) {
      ok = ok.where((i) => !i.startTime.isBefore(notBefore));
    }
    if (ok.isEmpty) return null;
    final it = arriveBy
        ? ok.reduce((a, b) => a.startTime.isAfter(b.startTime) ? a : b)
        : ok.reduce((a, b) => a.endTime.isBefore(b.endTime) ? a : b);
    // local time throughout: reminders fire on the phone's clock and the stored copy round-trips as local
    return ScheduledTripPlan(
      occurrence: occurrence.toLocal(),
      leaveAt: it.startTime.toLocal(),
      arriveAt: it.endTime.toLocal(),
      routes: [for (final l in it.legs) if (l.transit && l.route != null) l.route!.shortName],
      computedAt: now,
      realtime: it.hasRealtime,
    );
  }
}
