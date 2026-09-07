import '../../core/models/models.dart';
import '../../l10n/generated/app_localizations.dart';

/// What the "pensando…" line says while a tool runs.
///
/// A tool this build does not know about falls back to the plain "pensando…"
/// rather than showing a raw function name: the server may gain tools before
/// the app ships a string for them.
String assistantToolLabel(String tool, AppLocalizations l10n) => switch (tool) {
      'plan_trip' => l10n.assistantToolPlanTrip,
      'find_place' => l10n.assistantToolFindPlace,
      'next_departures' => l10n.assistantToolNextDepartures,
      'locate_bus' => l10n.assistantToolLocateBus,
      'service_alerts' => l10n.assistantToolServiceAlerts,
      'fare_estimate' => l10n.assistantToolFareEstimate,
      'nearby_stops' => l10n.assistantToolNearbyStops,
      'bike_stations' => l10n.assistantToolBikeStations,
      'vehicles_near' => l10n.assistantToolVehiclesNear,
      'route_info' => l10n.assistantToolRouteInfo,
      _ => l10n.assistantThinking,
    };

/// The one sentence shown for a refusal. Each documented code says what the
/// user can do next; an unknown code reads as the provider being down, which
/// is the honest description of a failure we cannot name.
String assistantErrorText(String code, AppLocalizations l10n) =>
    switch (assistantErrorKind(code)) {
      AssistantErrorKind.budget => l10n.assistantErrBudget,
      AssistantErrorKind.disabled => l10n.assistantErrDisabled,
      AssistantErrorKind.rateLimited => l10n.assistantErrRate,
      AssistantErrorKind.upstream => l10n.assistantErrUpstream,
    };

/// Whether to offer the assistant at all: the city has to have it on and the
/// API has to be reachable, since the model answers only from our tools.
bool assistantAvailable(City? city, {required bool online}) =>
    online && (city?.config.assistant.enabled ?? false);
