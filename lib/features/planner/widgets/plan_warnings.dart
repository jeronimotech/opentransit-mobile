import 'package:flutter/material.dart';

import '../../../core/theme/semantic_colors.dart';
import '../../../l10n/generated/app_localizations.dart';

/// What the router could not do, shown instead of thrown away.
///
/// `PlanResponse.warnings` has been parsed by the client since v1.4 and rendered nowhere, so two
/// of these have been invisible the whole time: a shared-vehicle mode dropped because no network
/// has vehicles, and a park & ride search that found no legal parking. The step-free warnings are
/// the reason this exists now — in seven of our nine cities the accessibility toggle cannot filter
/// anything, and results that look identical to an unfiltered search are a silent lie.
///
/// The server sends `CODE: sentence`. Known codes are localised; an unknown code falls back to the
/// server's own sentence, which is in English but beats showing the rider nothing.
class PlanWarnings extends StatelessWidget {
  const PlanWarnings({super.key, required this.warnings});
  final List<String> warnings;

  /// Codes we deliberately swallow. NO_ITINERARIES is the empty state's job, not a note above a
  /// list that is, by definition, not there.
  static const _hidden = {'NO_ITINERARIES'};

  /// The localised line for one `CODE: sentence` warning, or null to hide it.
  static String? line(AppLocalizations l10n, String warning) {
    final code = warning.split(':').first.trim();
    if (_hidden.contains(code)) return null;
    final text = switch (code) {
      'ACCESSIBILITY_UNVERIFIED' => l10n.warnAccessibilityUnverified,
      'ACCESSIBILITY_NO_DATA' => l10n.warnAccessibilityNoData,
      'MODE_NO_VEHICLES' => l10n.warnNoSharedVehicles,
      'PARK_RIDE_NO_PARKING' => l10n.warnNoParkRide,
      // OTP's own RoutingErrorCode values. `plan_from_otp` forwards them verbatim with OTP's
      // English description, so before these existed a Spanish rider was shown English — and these
      // are the warnings most often seen, because they are the reason a search found nothing.
      'WALKING_BETTER_THAN_TRANSIT' => l10n.warnWalkingBetter,
      'NO_TRANSIT_CONNECTION' => l10n.warnNoTransitConnection,
      'NO_TRANSIT_CONNECTION_IN_SEARCH_WINDOW' => l10n.warnNoTransitInWindow,
      'OUTSIDE_SERVICE_PERIOD' => l10n.warnOutsideServicePeriod,
      'OUTSIDE_BOUNDS' => l10n.warnOutsideBounds,
      'LOCATION_NOT_FOUND' => l10n.warnLocationNotFound,
      'NO_STOPS_IN_RANGE' => l10n.warnNoStopsInRange,
      'SYSTEM_ERROR' => l10n.warnRouterError,
      _ => null,
    };
    if (text != null) return text;
    // An unknown code still carries a sentence. It is in English, which is worse than a translation
    // and much better than a server telling the rider something the app drops on the floor.
    final fallback = warning.contains(':') ? warning.split(':').skip(1).join(':').trim() : warning;
    return fallback.isEmpty ? null : fallback;
  }

  /// True when any warning says the step-free filter could not do its job. The results screen uses
  /// this to blame the data rather than the city when the list comes back empty.
  static bool hasAccessibilityGap(List<String> warnings) => warnings.any((w) =>
      w.startsWith('ACCESSIBILITY_UNVERIFIED') || w.startsWith('ACCESSIBILITY_NO_DATA'));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lines = [for (final w in warnings) ?line(l10n, w)];
    if (lines.isEmpty) return const SizedBox.shrink();
    final color = context.semantic.disruption;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final text in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 14, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(text,
                        style: TextStyle(fontSize: 11, height: 1.35,
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
