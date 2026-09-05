import '../../core/models/models.dart';

/// What the muted line under "Próximos buses" should say, so "Programado"
/// rows are explained: no live buses on the route at all, buses on the route
/// but none heading to this stop yet, or N heading here.
enum LocateStatusKind { noLive, noneComing, coming }

class LocateStatus {
  const LocateStatus(this.kind, {this.onRoute = 0, this.coming = 0});
  final LocateStatusKind kind;

  /// Live buses on the route (any direction).
  final int onRoute;

  /// Rows backed by a live/estimated vehicle heading to this stop.
  final int coming;

  @override
  bool operator ==(Object other) =>
      other is LocateStatus && other.kind == kind && other.onRoute == onRoute && other.coming == coming;

  @override
  int get hashCode => Object.hash(kind, onRoute, coming);

  @override
  String toString() => 'LocateStatus($kind, onRoute: $onRoute, coming: $coming)';
}

/// [vehiclesOnRoute] is the API's count; when the API predates it, the live
/// [frame] is counted for the route ids / short name instead.
LocateStatus locateStatus({
  int? vehiclesOnRoute,
  required List<NextBus> next,
  VehicleFrame? frame,
  List<String> routeIds = const [],
  String? shortName,
}) {
  final coming = next.where((n) => n.vehicle != null && (n.source == 'live' || n.source == 'estimated')).length;
  int? onRoute = vehiclesOnRoute;
  if (onRoute == null && frame != null) {
    onRoute = frame.vehicles.values
        .where((v) => routeIds.contains(v.routeId) || (shortName != null && v.routeShortName == shortName))
        .length;
  }
  if (onRoute == null) {
    return coming == 0 ? const LocateStatus(LocateStatusKind.noLive) : LocateStatus(LocateStatusKind.coming, onRoute: coming, coming: coming);
  }
  if (onRoute == 0) return const LocateStatus(LocateStatusKind.noLive);
  if (coming == 0) return LocateStatus(LocateStatusKind.noneComing, onRoute: onRoute);
  return LocateStatus(LocateStatusKind.coming, onRoute: onRoute < coming ? coming : onRoute, coming: coming);
}
