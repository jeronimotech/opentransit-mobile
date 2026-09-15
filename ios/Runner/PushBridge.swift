//
//  PushBridge.swift
//  Runner side of the `opentransit/push` method channel (v2.3 scheduled-trip reminders).
//
//  Dart asks `register`; the token comes back as `onToken` (hex). A silent push (`content-available`)
//  is handed to Dart as `refresh`, which re-plans the trips leaving soon and adjusts their reminders;
//  the fetch completion waits for it (bounded) so iOS keeps granting background time.
//
import Flutter
import UIKit

final class PushBridge {
  static let channelName = "opentransit/push"
  static var channel: FlutterMethodChannel?
  private static var pendingToken: String?

  static func register(with registrar: FlutterPluginRegistrar) {
    let ch = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    channel = ch
    ch.setMethodCallHandler { call, result in
      switch call.method {
      case "register":
        DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
        if let t = pendingToken { ch.invokeMethod("onToken", arguments: t) }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  static func tokenReceived(_ deviceToken: Data) {
    let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
    pendingToken = hex
    channel?.invokeMethod("onToken", arguments: hex)
  }

  /// A remote notification while the app runs or is suspended. Returns false when it is not ours.
  static func handle(_ userInfo: [AnyHashable: Any], completion: @escaping (UIBackgroundFetchResult) -> Void) -> Bool {
    guard let kind = userInfo["kind"] as? String, kind == "tripRefresh", let ch = channel else { return false }
    var done = false
    let finish: (UIBackgroundFetchResult) -> Void = { r in
      if !done { done = true; completion(r) }
    }
    ch.invokeMethod("refresh", arguments: nil) { reply in
      let n = (reply as? NSNumber)?.intValue ?? 0
      finish(n > 0 ? .newData : .noData)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 25) { finish(.noData) }
    return true
  }
}
