//  WatchModels.swift
//  The snapshot the phone pushes, and the compact payload the API serves.

import Foundation

/// Mirrors `WatchFavourite` on the Dart side.
struct WatchFavourite: Codable, Hashable, Identifiable {
  var kind: String
  var id: String
  var label: String
  var routeId: String?
  var color: String?
  var lat: Double?
  var lon: Double?
}

/// Mirrors `WatchGoState`: what the phone is doing right now.
struct WatchGoState: Codable, Hashable {
  var active: Bool = false
  var nextStopName: String?
  var minutesToNextStop: Int?
  var routeShortName: String?
  var routeColor: String?
  var etaEpochSeconds: Double?
  var alight: Bool = false

  var etaAt: Date? { etaEpochSeconds.map { Date(timeIntervalSince1970: $0) } }
  static let idle = WatchGoState()
}

/// Everything the watch knows, persisted so a cold launch on the wrist shows
/// the last board instead of an empty screen.
struct WatchSnapshot: Codable, Hashable {
  var cityId: String = ""
  var cityName: String = ""
  var apiBaseUrl: String = ""
  var favourites: [WatchFavourite] = []
  var go: WatchGoState = .idle
  var analyticsEnabled: Bool = true
  var sentAt: Double = 0

  var isEmpty: Bool { cityId.isEmpty || apiBaseUrl.isEmpty }
}

// MARK: - /v1/cities/{city}/watch/summary

struct WatchSummary: Codable {
  var generatedAt: String?
  var items: [WatchItem] = []
  var alerts: Int = 0
}

struct WatchItem: Codable, Identifiable, Hashable {
  var kind: String?
  var stopId: String
  var stopName: String
  var component: String?
  var routes: [WatchRoute] = []

  var id: String { stopId }
}

struct WatchRoute: Codable, Identifiable, Hashable {
  var routeId: String
  var shortName: String
  var color: String?
  var next: [WatchDeparture] = []

  var id: String { routeId }
}

struct WatchDeparture: Codable, Hashable {
  var minutes: Int
  var realtime: Bool

  /// "Ya" reads better than "0 min" on a 40 mm screen.
  var label: String { minutes <= 0 ? "Ya" : "\(minutes) min" }
}
