//  WatchStore.swift
//  The watch's single source of truth: the phone's snapshot, the last
//  departure board, and how old it is.

import Combine
import Foundation
import WatchConnectivity

@MainActor
final class WatchStore: NSObject, ObservableObject {
  static let shared = WatchStore()

  @Published private(set) var snapshot = WatchSnapshot()
  @Published private(set) var summary: WatchSummary?
  @Published private(set) var fetchedAt: Date?
  @Published private(set) var loading = false
  @Published private(set) var lastError: String?

  private let defaults = UserDefaults.standard
  private let snapshotKey = "watch.snapshot"
  private let summaryKey = "watch.summary"
  private let fetchedKey = "watch.fetchedAt"

  /// Nothing on the wrist should ever say "loading" on a cold launch if we
  /// have something from last time, so both caches are restored eagerly.
  override private init() {
    super.init()
    snapshot = decode(snapshotKey) ?? WatchSnapshot()
    summary = decode(summaryKey)
    if let t = defaults.object(forKey: fetchedKey) as? Double { fetchedAt = Date(timeIntervalSince1970: t) }
    activateSession()
  }

  var isStale: Bool {
    guard let fetchedAt else { return true }
    return Date().timeIntervalSince(fetchedAt) > 90
  }

  var ageText: String? {
    guard let fetchedAt else { return nil }
    let s = Int(Date().timeIntervalSince(fetchedAt))
    if s < 60 { return "hace \(max(0, s)) s" }
    if s < 3600 { return "hace \(s / 60) min" }
    return "hace \(s / 3600) h"
  }

  // MARK: - Phone link

  private func activateSession() {
    guard WCSession.isSupported() else { return }
    let s = WCSession.default
    s.delegate = self
    s.activate()
  }

  private func apply(context: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: context),
          let next = try? JSONDecoder().decode(WatchSnapshot.self, from: data)
    else { return }
    snapshot = next
    persist(snapshotKey, next)
    Task { await refresh() }
  }

  // MARK: - API

  /// Pulls the compact board. Uses the phone's configured base URL, so a
  /// sandbox build on the phone points the watch at the sandbox too.
  func refresh() async {
    guard !snapshot.isEmpty, !loading else { return }
    loading = true
    defer { loading = false }
    guard let url = summaryURL() else { return }
    do {
      var req = URLRequest(url: url)
      req.timeoutInterval = 12
      let (data, response) = try await URLSession.shared.data(for: req)
      guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
        lastError = "HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)"
        return
      }
      let decoded = try JSONDecoder().decode(WatchSummary.self, from: data)
      summary = decoded
      fetchedAt = Date()
      lastError = nil
      persist(summaryKey, decoded)
      defaults.set(fetchedAt!.timeIntervalSince1970, forKey: fetchedKey)
      ComplicationRefresher.reload()
    } catch {
      lastError = error.localizedDescription
    }
  }

  private func summaryURL() -> URL? {
    var c = URLComponents(string: "\(snapshot.apiBaseUrl)/v1/cities/\(snapshot.cityId)/watch/summary")
    var q: [URLQueryItem] = [URLQueryItem(name: "limit", value: "3")]
    let stops = snapshot.favourites.filter { $0.kind == "stop" || $0.kind == "route_at_stop" }.map(\.id)
    if !stops.isEmpty { q.append(URLQueryItem(name: "stops", value: stops.prefix(6).joined(separator: ","))) }
    let routes = snapshot.favourites.compactMap(\.routeId)
    if !routes.isEmpty { q.append(URLQueryItem(name: "routes", value: routes.prefix(6).joined(separator: ","))) }
    if let f = snapshot.favourites.first(where: { $0.lat != nil && $0.lon != nil }) {
      q.append(URLQueryItem(name: "lat", value: String(f.lat!)))
      q.append(URLQueryItem(name: "lon", value: String(f.lon!)))
    }
    c?.queryItems = q
    return c?.url
  }

  // MARK: - Persistence

  private func persist<T: Encodable>(_ key: String, _ value: T) {
    if let d = try? JSONEncoder().encode(value) { defaults.set(d, forKey: key) }
  }

  private func decode<T: Decodable>(_ key: String) -> T? {
    guard let d = defaults.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(T.self, from: d)
  }
}

extension WatchStore: WCSessionDelegate {
  nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
    let ctx = session.receivedApplicationContext
    guard !ctx.isEmpty else { return }
    Task { @MainActor in self.apply(context: ctx) }
  }

  nonisolated func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
    Task { @MainActor in self.apply(context: context) }
  }
}
