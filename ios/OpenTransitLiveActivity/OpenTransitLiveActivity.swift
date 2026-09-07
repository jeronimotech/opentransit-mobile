//  OpenTransitLiveActivity.swift
//  Lock screen + Dynamic Island presentation of a trip in progress.
//
//  Copy is Spanish because the activity is city-facing and the app ships
//  Spanish first; the strings are short enough that the English build reads
//  fine too ("Bájate en …" is the one line riders actually look for).

import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.2, *)
struct OpenTransitLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: OpenTransitActivityAttributes.self) { context in
      LockScreenView(context: context)
        .activityBackgroundTint(Color.black.opacity(0.55))
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          RouteBadge(shortName: context.attributes.routeShortName,
                     colorHex: context.attributes.routeColor)
            .padding(.leading, 4)
        }
        DynamicIslandExpandedRegion(.trailing) {
          VStack(alignment: .trailing, spacing: 0) {
            Text(context.state.etaAt, style: .time)
              .font(.system(.title3, design: .rounded).weight(.bold))
              .monospacedDigit()
            Text("llegada").font(.caption2).foregroundStyle(.secondary)
          }
          .padding(.trailing, 4)
        }
        DynamicIslandExpandedRegion(.center) {
          Text(headline(context.state, destination: context.attributes.destination))
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(spacing: 4) {
            ProgressView(value: context.state.progress)
              .tint(Color(hexOrBrand: context.attributes.routeColor))
            Text("Tramo \(context.state.legIndex + 1) de \(context.state.totalLegs)")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
      } compactLeading: {
        RouteBadge(shortName: context.attributes.routeShortName,
                   colorHex: context.attributes.routeColor, compact: true)
      } compactTrailing: {
        Text(minutesLabel(context.state))
          .font(.system(.caption, design: .rounded).weight(.bold))
          .monospacedDigit()
      } minimal: {
        Text(minutesLabel(context.state))
          .font(.system(.caption2, design: .rounded).weight(.bold))
          .monospacedDigit()
      }
      .widgetURL(URL(string: "opentransit://\(context.attributes.cityId)/go"))
      .keylineTint(Color(hexOrBrand: context.attributes.routeColor))
    }
  }

  /// "Bájate en Portal Sur · 4 min", or the arrival line once the trip ends.
  private func headline(_ s: OpenTransitActivityAttributes.ContentState,
                        destination: String) -> String {
    if s.isArrived { return "Llegaste a \(destination)" }
    if s.nextStopName.isEmpty { return "En camino" }
    return "Bájate en \(s.nextStopName) · \(s.clampedMinutes) min"
  }

  private func minutesLabel(_ s: OpenTransitActivityAttributes.ContentState) -> String {
    s.isArrived ? "✓" : "\(s.clampedMinutes)m"
  }
}

@available(iOS 16.2, *)
private struct LockScreenView: View {
  let context: ActivityViewContext<OpenTransitActivityAttributes>

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        RouteBadge(shortName: context.attributes.routeShortName,
                   colorHex: context.attributes.routeColor)
        Text(context.attributes.tripLabel)
          .font(.system(.footnote, design: .rounded))
          .foregroundStyle(.secondary)
          .lineLimit(1)
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 0) {
          Text(context.state.etaAt, style: .time)
            .font(.system(.title3, design: .rounded).weight(.bold))
            .monospacedDigit()
          Text(context.state.isDelayed ? "con retraso" : "llegada")
            .font(.caption2)
            .foregroundStyle(context.state.isDelayed ? .orange : .secondary)
        }
      }

      Text(headline)
        .font(.system(.headline, design: .rounded))
        .lineLimit(2)
        .minimumScaleFactor(0.85)

      VStack(alignment: .leading, spacing: 3) {
        ProgressView(value: context.state.progress)
          .tint(Color(hexOrBrand: context.attributes.routeColor))
        Text("Tramo \(context.state.legIndex + 1) de \(context.state.totalLegs)")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .padding(14)
  }

  private var headline: String {
    let s = context.state
    if s.isArrived { return "Llegaste a \(context.attributes.destination)" }
    if s.nextStopName.isEmpty { return "En camino a \(context.attributes.destination)" }
    return "Bájate en \(s.nextStopName) · \(s.clampedMinutes) min"
  }
}
