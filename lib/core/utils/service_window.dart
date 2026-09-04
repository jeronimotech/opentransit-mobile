import '../models/models.dart';

/// Status of a route's service window, ready for display.
enum ServiceStatus { unknown, active, outOfHours, endedForToday }

ServiceStatus serviceStatus(ServiceWindow? w) {
  if (w == null) return ServiceStatus.unknown;
  if (w.active) return ServiceStatus.active;
  return w.nextStart == null ? ServiceStatus.endedForToday : ServiceStatus.outOfHours;
}

/// `04:00 – 23:00`, or null when the window is unknown.
String? serviceSpan(ServiceWindow? w) {
  if (w == null || w.start == null || w.end == null) return null;
  return '${w.start} – ${w.end}';
}

/// Short human label: `null` while running, `Fuera de horario · próximo 04:30`
/// when the route starts later today, `Sin servicio hoy` when it is done.
String? serviceHint(
  ServiceWindow? w, {
  required String outOfHours,
  required String Function(String time) nextAt,
  required String noMoreToday,
}) =>
    switch (serviceStatus(w)) {
      ServiceStatus.active || ServiceStatus.unknown => null,
      ServiceStatus.outOfHours => '$outOfHours · ${nextAt(w!.nextStart!)}',
      ServiceStatus.endedForToday => noMoreToday,
    };
