import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';

class PlannerState {
  const PlannerState({
    this.from,
    this.to,
    this.time,
    this.arriveBy = false,
    this.modes = const {TravelMode.transit, TravelMode.walk},
    this.onDemand = false,
    this.result,
    this.request,
  });
  final Place? from;
  final Place? to;

  /// `null` means "now".
  final DateTime? time;
  final bool arriveBy;
  final Set<TravelMode> modes;

  /// Ask for taxi / ride-hailing options too (v1.4).
  final bool onDemand;
  final AsyncValue<PlanResponse>? result;
  final PlanRequest? request;

  bool get canPlan => from != null && to != null;

  PlannerState copyWith({
    Place? from,
    bool clearFrom = false,
    Place? to,
    bool clearTo = false,
    DateTime? time,
    bool clearTime = false,
    bool? arriveBy,
    Set<TravelMode>? modes,
    bool? onDemand,
    AsyncValue<PlanResponse>? result,
    bool clearResult = false,
    PlanRequest? request,
  }) =>
      PlannerState(
        from: clearFrom ? null : (from ?? this.from),
        to: clearTo ? null : (to ?? this.to),
        time: clearTime ? null : (time ?? this.time),
        arriveBy: arriveBy ?? this.arriveBy,
        modes: modes ?? this.modes,
        onDemand: onDemand ?? this.onDemand,
        result: clearResult ? null : (result ?? this.result),
        request: request ?? this.request,
      );
}

class PlannerNotifier extends Notifier<PlannerState> {
  @override
  PlannerState build() => const PlannerState();

  void setFrom(Place? p) =>
      state = state.copyWith(from: p, clearFrom: p == null, clearResult: true);
  void setTo(Place? p) =>
      state = state.copyWith(to: p, clearTo: p == null, clearResult: true);
  void swap() => state = PlannerState(
        from: state.to,
        to: state.from,
        time: state.time,
        arriveBy: state.arriveBy,
        modes: state.modes,
        onDemand: state.onDemand,
      );
  void setTime(DateTime? t) =>
      state = state.copyWith(time: t, clearTime: t == null, clearResult: true);
  void setArriveBy(bool v) =>
      state = state.copyWith(arriveBy: v, clearResult: true);

  void toggleMode(TravelMode m) {
    final next = Set<TravelMode>.from(state.modes);
    if (!next.remove(m)) next.add(m);
    if (next.isEmpty) next.add(TravelMode.walk);
    state = state.copyWith(modes: next, clearResult: true);
  }

  void setOnDemand(bool v) => state = state.copyWith(onDemand: v, clearResult: true);

  void setModes(Set<TravelMode> modes) =>
      state = state.copyWith(modes: modes.isEmpty ? {TravelMode.walk} : modes, clearResult: true);

  void reset() => state = const PlannerState();

  /// Runs the plan against the API and stores the result in [PlannerState.result].
  Future<PlanResponse?> plan(String cityId) async {
    final s = state;
    if (s.from == null || s.to == null) return null;
    final settings = ref.read(settingsProvider);
    final req = PlanRequest(
      from: s.from!,
      to: s.to!,
      time: s.time,
      arriveBy: s.arriveBy,
      modes: s.modes.toList(),
      wheelchair: settings.wheelchair,
      maxWalkDistance: settings.maxWalkDistance,
      locale: settings.locale?.languageCode ?? 'es',
      onDemand: s.onDemand,
      numItineraries: s.onDemand ? 6 : 5,
    );
    state = state.copyWith(result: const AsyncValue.loading(), request: req);
    try {
      final res = await ref.read(apiClientProvider).plan(cityId, req);
      state = state.copyWith(result: AsyncValue.data(res));
      return res;
    } catch (e, st) {
      state = state.copyWith(result: AsyncValue.error(e, st));
      return null;
    }
  }
}

final plannerProvider =
    NotifierProvider<PlannerNotifier, PlannerState>(PlannerNotifier.new);
