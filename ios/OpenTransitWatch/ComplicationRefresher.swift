//  ComplicationRefresher.swift
//  Nudges WidgetKit after a successful fetch so the face shows the same
//  minutes as the app.

import Foundation
import WidgetKit

enum ComplicationRefresher {
  static func reload() {
    WidgetCenter.shared.reloadTimelines(ofKind: "OpenTransitNextDeparture")
  }
}
