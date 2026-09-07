//  OpenTransitWatchApp.swift

import SwiftUI

@main
struct OpenTransitWatchApp: App {
  @Environment(\.scenePhase) private var phase

  var body: some Scene {
    WindowGroup {
      WatchRootView()
    }
    .onChange(of: phase) { _, new in
      // Coming back to the wrist is the moment the board is most likely stale.
      if new == .active { Task { await WatchStore.shared.refresh() } }
    }
  }
}
