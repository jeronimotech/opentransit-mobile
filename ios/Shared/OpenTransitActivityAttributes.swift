//  OpenTransitActivityAttributes.swift
//  Shared by the Runner app (which starts and updates the activity) and the
//  OpenTransitLiveActivity widget extension (which draws it). Both targets
//  compile this same file, so the ActivityKit type identity matches.

import Foundation

#if canImport(ActivityKit)
import ActivityKit

/// Everything a running trip shows on the lock screen and in the Dynamic Island.
///
/// The split follows ActivityKit's contract: `OpenTransitActivityAttributes`
/// is fixed for the life of the trip, `ContentState` is what we push on every
/// leg change or ETA refresh.
@available(iOS 16.2, *)
struct OpenTransitActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    /// Arrival at the final destination.
    var etaAt: Date
    /// Minutes to the alighting point of the current leg. Negative is clamped
    /// to zero by the views: "in -1 min" would be nonsense on a lock screen.
    var minutesToNextStop: Int
    /// Where the traveller gets off next.
    var nextStopName: String
    /// 0-based, so the views render `legIndex + 1` of `totalLegs`.
    var legIndex: Int
    var totalLegs: Int
    /// One of: on_time, delayed, arrived, cancelled.
    var state: String

    var isArrived: Bool { state == "arrived" }
    var isDelayed: Bool { state == "delayed" }
    /// Fraction of the itinerary completed, for the progress bar.
    var progress: Double {
      guard totalLegs > 0 else { return 0 }
      if isArrived { return 1 }
      return min(1, max(0, Double(legIndex) / Double(totalLegs)))
    }
    var clampedMinutes: Int { max(0, minutesToNextStop) }
  }

  /// "Portal Norte → Portal Sur", shown as the activity's title.
  var tripLabel: String
  /// Final destination name.
  var destination: String
  /// Route badge, e.g. "G12". Empty for a walking-only trip.
  var routeShortName: String
  /// "#RRGGBB" of the route, used for the badge background.
  var routeColor: String
  /// City slug, so tapping the activity deep-links back into the right city.
  var cityId: String
}
#endif
