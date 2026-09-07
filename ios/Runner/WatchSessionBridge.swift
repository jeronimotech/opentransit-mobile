//  WatchSessionBridge.swift
//  Phone half of the watch link: pushes city, favourites and GO state to the
//  paired Apple Watch over WatchConnectivity.
//
//  Application context (not messages) is deliberate: it survives the watch
//  being asleep and only the latest snapshot matters — a departure board from
//  three minutes ago is worse than none.

import Flutter
import Foundation

#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

final class WatchSessionBridge: NSObject {
  static let channelName = "opentransit/watch"
  static let shared = WatchSessionBridge()

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    shared.activate()
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isSupported":
        result(shared.isSupported)
      case "isPaired":
        result(shared.isPaired)
      case "sync":
        result(shared.send(call.arguments as? [String: Any] ?? [:]))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private var isSupported: Bool {
    #if canImport(WatchConnectivity)
    return WCSession.isSupported()
    #else
    return false
    #endif
  }

  private var isPaired: Bool {
    #if canImport(WatchConnectivity)
    guard WCSession.isSupported() else { return false }
    let s = WCSession.default
    return s.isPaired && s.isWatchAppInstalled
    #else
    return false
    #endif
  }

  private func activate() {
    #if canImport(WatchConnectivity)
    guard WCSession.isSupported() else { return }
    let s = WCSession.default
    s.delegate = self
    if s.activationState != .activated { s.activate() }
    #endif
  }

  /// Replaces the watch's snapshot. Returns false when there is no watch to
  /// talk to, which the Dart side treats as "not an error, just no watch".
  @discardableResult
  private func send(_ payload: [String: Any]) -> Bool {
    #if canImport(WatchConnectivity)
    guard WCSession.isSupported() else { return false }
    let s = WCSession.default
    guard s.activationState == .activated, s.isPaired else { return false }
    do {
      var ctx = payload
      ctx["sentAt"] = Date().timeIntervalSince1970
      try s.updateApplicationContext(ctx)
      return true
    } catch {
      NSLog("watch sync failed: \(error.localizedDescription)")
      return false
    }
    #else
    return false
    #endif
  }
}

#if canImport(WatchConnectivity)
extension WatchSessionBridge: WCSessionDelegate {
  func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState,
               error: Error?) {}
  func sessionDidBecomeInactive(_ session: WCSession) {}
  // Re-activate after the user switches watches, otherwise the link dies
  // silently until the next app launch.
  func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
}
#endif
