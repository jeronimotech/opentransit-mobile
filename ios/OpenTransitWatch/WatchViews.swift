//  WatchViews.swift
//  Three screens: Cerca de ti, Ubica tu bus, and the GO mirror.

import SwiftUI
import WatchKit

// MARK: - Shared bits

extension Color {
  init(hexOrBrand hex: String?) {
    var s = (hex ?? "").trimmingCharacters(in: .whitespaces)
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

struct RouteChip: View {
  let name: String
  let color: String?
  var body: some View {
    Text(name)
      .font(.system(size: 13, weight: .heavy, design: .rounded))
      .lineLimit(1)
      .minimumScaleFactor(0.7)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(Color(hexOrBrand: color), in: RoundedRectangle(cornerRadius: 5))
      .foregroundStyle(.white)
  }
}

/// One line explaining where the numbers come from — the watch is the screen
/// where a stale board is most likely to be believed.
struct FreshnessLine: View {
  @ObservedObject var store = WatchStore.shared
  var body: some View {
    if let age = store.ageText {
      Text(store.isStale ? "Sin conexión · \(age)" : "Actualizado \(age)")
        .font(.caption2)
        .foregroundStyle(store.isStale ? .orange : .secondary)
    } else if store.loading {
      Text("Cargando…").font(.caption2).foregroundStyle(.secondary)
    }
  }
}

// MARK: - 1. Cerca de ti

struct NearbyView: View {
  @ObservedObject var store = WatchStore.shared

  var body: some View {
    List {
      if store.snapshot.isEmpty {
        emptyState
      } else if let items = store.summary?.items, !items.isEmpty {
        ForEach(items) { item in
          Section(item.stopName) {
            ForEach(item.routes) { route in
              HStack(spacing: 6) {
                RouteChip(name: route.shortName, color: route.color)
                Spacer(minLength: 2)
                ForEach(Array(route.next.prefix(2)), id: \.self) { d in
                  HStack(spacing: 2) {
                    if d.realtime {
                      Circle().fill(.green).frame(width: 5, height: 5)
                    }
                    Text(d.label)
                      .font(.system(.footnote, design: .rounded).weight(.semibold))
                      .monospacedDigit()
                  }
                }
                if route.next.isEmpty {
                  Text("—").font(.footnote).foregroundStyle(.secondary)
                }
              }
            }
          }
        }
        Section { FreshnessLine() }
      } else {
        Section { Text("Sin paradas guardadas").font(.footnote).foregroundStyle(.secondary) }
      }
    }
    .navigationTitle("Cerca de ti")
    .task { await store.refresh() }
    .refreshable { await store.refresh() }
  }

  private var emptyState: some View {
    VStack(spacing: 6) {
      Image(systemName: "iphone.gen3").font(.title3).foregroundStyle(.secondary)
      Text("Abre opentransit en el iPhone para sincronizar tu ciudad.")
        .font(.caption2).multilineTextAlignment(.center)
    }
  }
}

// MARK: - 2. Ubica tu bus

struct LocateView: View {
  @ObservedObject var store = WatchStore.shared

  private var routeFavourites: [WatchFavourite] {
    store.snapshot.favourites.filter { $0.routeId != nil }
  }

  var body: some View {
    List {
      if routeFavourites.isEmpty {
        Text("Guarda una ruta en el iPhone para verla aquí.")
          .font(.caption2).foregroundStyle(.secondary)
      } else {
        ForEach(routeFavourites) { fav in
          Section(fav.label) {
            let times = departures(for: fav)
            if times.isEmpty {
              Text("Sin buses en vivo").font(.footnote).foregroundStyle(.secondary)
            } else {
              ForEach(Array(times.prefix(3)), id: \.self) { d in
                HStack {
                  if d.realtime {
                    Circle().fill(.green).frame(width: 6, height: 6)
                  } else {
                    Image(systemName: "clock").font(.caption2).foregroundStyle(.secondary)
                  }
                  Text(d.label).font(.system(.body, design: .rounded).weight(.semibold)).monospacedDigit()
                  Spacer()
                  Text(d.realtime ? "En vivo" : "Programado").font(.caption2).foregroundStyle(.secondary)
                }
              }
            }
          }
        }
        Section { FreshnessLine() }
      }
    }
    .navigationTitle("Ubica tu bus")
    .task { await store.refresh() }
    .refreshable { await store.refresh() }
  }

  private func departures(for fav: WatchFavourite) -> [WatchDeparture] {
    guard let items = store.summary?.items else { return [] }
    for item in items where item.stopId == fav.id {
      for r in item.routes where r.routeId == fav.routeId { return r.next }
    }
    return []
  }
}

// MARK: - 3. GO mirror

struct GoView: View {
  @ObservedObject var store = WatchStore.shared
  @State private var buzzedFor: String?

  private var go: WatchGoState { store.snapshot.go }

  var body: some View {
    VStack(spacing: 8) {
      if !go.active {
        Image(systemName: "figure.walk.motion").font(.title2).foregroundStyle(.secondary)
        Text("Sin viaje en curso").font(.footnote).foregroundStyle(.secondary)
        Text("Inicia un viaje en el iPhone").font(.caption2).foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      } else {
        if let r = go.routeShortName, !r.isEmpty {
          RouteChip(name: r, color: go.routeColor)
        }
        Text(go.alight ? "Bájate en la próxima" : "Próxima parada")
          .font(.caption)
          .foregroundStyle(go.alight ? .orange : .secondary)
        Text(go.nextStopName ?? "—")
          .font(.system(.headline, design: .rounded))
          .multilineTextAlignment(.center)
          .lineLimit(2)
          .minimumScaleFactor(0.8)
        if let m = go.minutesToNextStop {
          Text(m <= 0 ? "Ya" : "\(m) min")
            .font(.system(size: 34, weight: .bold, design: .rounded))
            .monospacedDigit()
        }
        if let eta = go.etaAt {
          Text("Llegas \(eta, style: .time)").font(.caption2).foregroundStyle(.secondary)
        }
      }
    }
    .padding(.horizontal, 6)
    .navigationTitle("Viaje")
    .onChange(of: go.alight) { _, alight in
      // One tap per stop, not per snapshot: the phone re-sends the same state
      // on every GPS fix.
      let key = go.nextStopName ?? ""
      guard alight, buzzedFor != key else { return }
      buzzedFor = key
      WKInterfaceDevice.current().play(.notification)
    }
  }
}

// MARK: - Root

struct WatchRootView: View {
  /// Screenshot hook: `simctl launch … -watchInitialTab 1` opens a given tab.
  /// Launch arguments land in UserDefaults, so this costs nothing at runtime
  /// and defaults to the first tab for real users.
  @State private var tab = UserDefaults.standard.integer(forKey: "watchInitialTab")

  var body: some View {
    TabView(selection: $tab) {
      NavigationStack { NearbyView() }.tag(0)
      NavigationStack { LocateView() }.tag(1)
      NavigationStack { GoView() }.tag(2)
    }
    .tabViewStyle(.verticalPage)
  }
}
