//  NextDepartureComplication.swift
//  Corner, circular and rectangular complications showing the next departure
//  of the pinned stop. The data comes from the same UserDefaults cache the
//  watch app writes, so the face never makes its own network call.

import SwiftUI
import WidgetKit

struct NextDepartureEntry: TimelineEntry {
  let date: Date
  let routeShortName: String
  let routeColor: String
  let stopName: String
  let minutes: Int?
  let realtime: Bool

  var minutesLabel: String {
    guard let minutes else { return "—" }
    return minutes <= 0 ? "Ya" : "\(minutes)"
  }

  static let placeholder = NextDepartureEntry(
    date: .now, routeShortName: "G12", routeColor: "#B71C1C",
    stopName: "Portal Norte", minutes: 4, realtime: true)
}

struct NextDepartureProvider: TimelineProvider {
  func placeholder(in context: Context) -> NextDepartureEntry { .placeholder }

  func getSnapshot(in context: Context, completion: @escaping (NextDepartureEntry) -> Void) {
    completion(context.isPreview ? .placeholder : current())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<NextDepartureEntry>) -> Void) {
    let entry = current()
    // Count the minutes down locally until the app refreshes: a face that
    // freezes on "4 min" for a quarter of an hour is worse than no face.
    var entries: [NextDepartureEntry] = [entry]
    if let m = entry.minutes, m > 0 {
      for step in 1...min(m, 10) {
        entries.append(NextDepartureEntry(
          date: entry.date.addingTimeInterval(Double(step) * 60),
          routeShortName: entry.routeShortName, routeColor: entry.routeColor,
          stopName: entry.stopName, minutes: m - step, realtime: entry.realtime))
      }
    }
    completion(Timeline(entries: entries, policy: .after(Date().addingTimeInterval(600))))
  }

  /// Reads the board the watch app cached; returns an empty entry when the
  /// phone has not synced yet.
  private func current() -> NextDepartureEntry {
    let d = UserDefaults.standard
    guard let data = d.data(forKey: "watch.summary"),
          let summary = try? JSONDecoder().decode(WatchSummary.self, from: data),
          let item = summary.items.first,
          let route = item.routes.first
    else {
      return NextDepartureEntry(date: .now, routeShortName: "", routeColor: "#B71C1C",
                                stopName: "opentransit", minutes: nil, realtime: false)
    }
    let fetched = d.object(forKey: "watch.fetchedAt") as? Double
    // Age the cached minutes so the face is honest about elapsed time.
    let elapsed = fetched.map { Int(Date().timeIntervalSince1970 - $0) / 60 } ?? 0
    let next = route.next.first
    return NextDepartureEntry(
      date: .now,
      routeShortName: route.shortName,
      routeColor: route.color ?? "#B71C1C",
      stopName: item.stopName,
      minutes: next.map { max(0, $0.minutes - elapsed) },
      realtime: next?.realtime ?? false)
  }
}

struct NextDepartureView: View {
  @Environment(\.widgetFamily) private var family
  let entry: NextDepartureEntry

  var body: some View {
    switch family {
    case .accessoryCorner:
      Text(entry.minutesLabel)
        .font(.system(.title2, design: .rounded).weight(.bold))
        .widgetCurvesContent()
        .widgetLabel { Text(entry.routeShortName.isEmpty ? entry.stopName : entry.routeShortName) }
    case .accessoryCircular:
      VStack(spacing: 0) {
        Text(entry.routeShortName.isEmpty ? "🚌" : entry.routeShortName)
          .font(.system(size: 11, weight: .bold, design: .rounded))
          .lineLimit(1).minimumScaleFactor(0.6)
        Text(entry.minutesLabel)
          .font(.system(size: 20, weight: .heavy, design: .rounded))
          .monospacedDigit()
      }
    default:
      HStack(spacing: 6) {
        if !entry.routeShortName.isEmpty {
          Text(entry.routeShortName)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(Color(hexOrBrandComplication: entry.routeColor),
                        in: RoundedRectangle(cornerRadius: 4))
        }
        VStack(alignment: .leading, spacing: 0) {
          Text(entry.stopName).font(.caption2).lineLimit(1)
          Text(entry.minutes == nil ? "Sin datos" : "\(entry.minutesLabel) min")
            .font(.system(.footnote, design: .rounded).weight(.semibold))
        }
        Spacer(minLength: 0)
      }
    }
  }
}

extension Color {
  init(hexOrBrandComplication hex: String) {
    var s = hex
    if s.hasPrefix("#") { s.removeFirst() }
    guard s.count == 6, let v = UInt32(s, radix: 16) else {
      self = Color(red: 0.72, green: 0.11, blue: 0.11)
      return
    }
    self = Color(red: Double((v >> 16) & 0xFF) / 255,
                 green: Double((v >> 8) & 0xFF) / 255,
                 blue: Double(v & 0xFF) / 255)
  }
}

struct NextDepartureComplication: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "OpenTransitNextDeparture", provider: NextDepartureProvider()) { entry in
      NextDepartureView(entry: entry).containerBackground(.clear, for: .widget)
    }
    .configurationDisplayName("Próximo bus")
    .description("Minutos para el próximo bus de tu parada fijada.")
    .supportedFamilies([.accessoryCorner, .accessoryCircular, .accessoryRectangular, .accessoryInline])
  }
}

@main
struct OpenTransitWatchComplicationsBundle: WidgetBundle {
  var body: some Widget { NextDepartureComplication() }
}
