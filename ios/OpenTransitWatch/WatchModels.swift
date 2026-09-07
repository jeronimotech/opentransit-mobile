//  WatchModels.swift
//  The snapshot the phone pushes, and the compact payload the API serves.

import Foundation

/// Mirrors `WatchFavourite` on the Dart side.
struct WatchFavourite: Codable, Hashable, Identifiable {
  var kind: String = "stop"
  var id: String = ""
  var label: String = ""
  var routeId: String?
  var color: String?
  var lat: Double?
  var lon: Double?

  init(kind: String, id: String, label: String, routeId: String? = nil,
       color: String? = nil, lat: Double? = nil, lon: Double? = nil) {
    self.kind = kind; self.id = id; self.label = label
    self.routeId = routeId; self.color = color; self.lat = lat; self.lon = lon
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    kind = (try? c.decodeIfPresent(String.self, forKey: .kind)) as? String ?? "stop"
    id = (try? c.decodeIfPresent(String.self, forKey: .id)) as? String ?? ""
    label = (try? c.decodeIfPresent(String.self, forKey: .label)) as? String ?? ""
    routeId = try? c.decodeIfPresent(String.self, forKey: .routeId)
    color = try? c.decodeIfPresent(String.self, forKey: .color)
    lat = try? c.decodeIfPresent(Double.self, forKey: .lat)
    lon = try? c.decodeIfPresent(Double.self, forKey: .lon)
  }
}

/// Mirrors `WatchGoState`: what the phone is doing right now.
///
/// Decoding is deliberately lenient. Swift's synthesized `Decodable` throws on
/// a missing key even when the property has a default, so one field the phone
/// happens not to send would blank the whole watch — the failure mode is a
/// wrist that says "open the app on your iPhone" while the phone is right
/// there. Every field is optional on the wire.
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

  init(active: Bool = false, nextStopName: String? = nil, minutesToNextStop: Int? = nil,
       routeShortName: String? = nil, routeColor: String? = nil,
       etaEpochSeconds: Double? = nil, alight: Bool = false) {
    self.active = active
    self.nextStopName = nextStopName
    self.minutesToNextStop = minutesToNextStop
    self.routeShortName = routeShortName
    self.routeColor = routeColor
    self.etaEpochSeconds = etaEpochSeconds
    self.alight = alight
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    active = (try? c.decodeIfPresent(Bool.self, forKey: .active)) as? Bool ?? false
    nextStopName = try? c.decodeIfPresent(String.self, forKey: .nextStopName)
    minutesToNextStop = try? c.decodeIfPresent(Int.self, forKey: .minutesToNextStop)
    routeShortName = try? c.decodeIfPresent(String.self, forKey: .routeShortName)
    routeColor = try? c.decodeIfPresent(String.self, forKey: .routeColor)
    etaEpochSeconds = try? c.decodeIfPresent(Double.self, forKey: .etaEpochSeconds)
    alight = (try? c.decodeIfPresent(Bool.self, forKey: .alight)) as? Bool ?? false
  }
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

  init() {}

  /// Lenient for the same reason as `WatchGoState`: a partial payload should
  /// degrade one field, never the whole screen.
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    cityId = (try? c.decodeIfPresent(String.self, forKey: .cityId)) as? String ?? ""
    cityName = (try? c.decodeIfPresent(String.self, forKey: .cityName)) as? String ?? ""
    apiBaseUrl = (try? c.decodeIfPresent(String.self, forKey: .apiBaseUrl)) as? String ?? ""
    favourites = (try? c.decodeIfPresent([WatchFavourite].self, forKey: .favourites)) as? [WatchFavourite] ?? []
    go = (try? c.decodeIfPresent(WatchGoState.self, forKey: .go)) as? WatchGoState ?? .idle
    analyticsEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .analyticsEnabled)) as? Bool ?? true
    sentAt = (try? c.decodeIfPresent(Double.self, forKey: .sentAt)) as? Double ?? 0
  }
}

// MARK: - /v1/cities/{city}/watch/summary

struct WatchSummary: Codable {
  var generatedAt: String?
  var items: [WatchItem] = []
  var alerts: Int = 0

  init(generatedAt: String? = nil, items: [WatchItem] = [], alerts: Int = 0) {
    self.generatedAt = generatedAt; self.items = items; self.alerts = alerts
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    generatedAt = try? c.decodeIfPresent(String.self, forKey: .generatedAt)
    items = (try? c.decodeIfPresent([WatchItem].self, forKey: .items)) as? [WatchItem] ?? []
    alerts = (try? c.decodeIfPresent(Int.self, forKey: .alerts)) as? Int ?? 0
  }
}

struct WatchItem: Codable, Identifiable, Hashable {
  var kind: String?
  var stopId: String = ""
  var stopName: String = ""
  var component: String?
  var routes: [WatchRoute] = []

  var id: String { stopId }

  init(kind: String? = nil, stopId: String, stopName: String,
       component: String? = nil, routes: [WatchRoute] = []) {
    self.kind = kind; self.stopId = stopId; self.stopName = stopName
    self.component = component; self.routes = routes
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    kind = try? c.decodeIfPresent(String.self, forKey: .kind)
    stopId = (try? c.decodeIfPresent(String.self, forKey: .stopId)) as? String ?? ""
    stopName = (try? c.decodeIfPresent(String.self, forKey: .stopName)) as? String ?? ""
    component = try? c.decodeIfPresent(String.self, forKey: .component)
    routes = (try? c.decodeIfPresent([WatchRoute].self, forKey: .routes)) as? [WatchRoute] ?? []
  }
}

struct WatchRoute: Codable, Identifiable, Hashable {
  var routeId: String = ""
  var shortName: String = ""
  var color: String?
  var next: [WatchDeparture] = []

  var id: String { routeId }

  init(routeId: String, shortName: String, color: String? = nil, next: [WatchDeparture] = []) {
    self.routeId = routeId; self.shortName = shortName; self.color = color; self.next = next
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    routeId = (try? c.decodeIfPresent(String.self, forKey: .routeId)) as? String ?? ""
    shortName = (try? c.decodeIfPresent(String.self, forKey: .shortName)) as? String ?? ""
    color = try? c.decodeIfPresent(String.self, forKey: .color)
    next = (try? c.decodeIfPresent([WatchDeparture].self, forKey: .next)) as? [WatchDeparture] ?? []
  }
}

struct WatchDeparture: Codable, Hashable {
  var minutes: Int = 0
  var realtime: Bool = false

  init(minutes: Int, realtime: Bool) { self.minutes = minutes; self.realtime = realtime }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    minutes = (try? c.decodeIfPresent(Int.self, forKey: .minutes)) as? Int ?? 0
    realtime = (try? c.decodeIfPresent(Bool.self, forKey: .realtime)) as? Bool ?? false
  }

  /// "Ya" reads better than "0 min" on a 40 mm screen.
  var label: String { minutes <= 0 ? "Ya" : "\(minutes) min" }
}
