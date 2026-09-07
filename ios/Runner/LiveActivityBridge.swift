//  LiveActivityBridge.swift
//  Runner side of the `opentransit/live_activity` method channel.
//
//  The app owns the activity's lifetime: GO starts it, every location fix or
//  leg change updates it, arrival or cancel ends it. No push tokens are
//  registered — while GO runs the app holds a foreground location session, so
//  local updates are enough and no APNs key is required.

import Flutter
import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

enum LiveActivityBridge {
  static let channelName = "opentransit/live_activity"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isSupported":
        result(isSupported())
      case "start":
        start(call.arguments as? [String: Any] ?? [:], result: result)
      case "update":
        update(call.arguments as? [String: Any] ?? [:], result: result)
      case "end":
        end(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func isSupported() -> Bool {
    #if canImport(ActivityKit)
    if #available(iOS 16.2, *) {
      return ActivityAuthorizationInfo().areActivitiesEnabled
    }
    #endif
    return false
  }

  #if canImport(ActivityKit)
  @available(iOS 16.2, *)
  private static var current: Activity<OpenTransitActivityAttributes>? {
    Activity<OpenTransitActivityAttributes>.activities.first
  }

  @available(iOS 16.2, *)
  private static func state(from a: [String: Any]) -> OpenTransitActivityAttributes.ContentState {
    // `etaAt` arrives as epoch seconds; anything missing degrades to "now"
    // rather than throwing, because a Live Activity is never worth a crash.
    let eta = (a["etaEpochSeconds"] as? Double).map { Date(timeIntervalSince1970: $0) } ?? Date()
    return .init(
      etaAt: eta,
      minutesToNextStop: a["minutesToNextStop"] as? Int ?? 0,
      nextStopName: a["nextStopName"] as? String ?? "",
      legIndex: a["legIndex"] as? Int ?? 0,
      totalLegs: max(1, a["totalLegs"] as? Int ?? 1),
      state: a["state"] as? String ?? "on_time")
  }
  #endif

  private static func start(_ args: [String: Any], result: @escaping FlutterResult) {
    #if canImport(ActivityKit)
    if #available(iOS 16.2, *) {
      guard ActivityAuthorizationInfo().areActivitiesEnabled else { return result(false) }
      // One trip at a time: a stale activity from a killed session would
      // otherwise sit on the lock screen next to the new one.
      Task { await endAll() }
      let attrs = OpenTransitActivityAttributes(
        tripLabel: args["tripLabel"] as? String ?? "",
        destination: args["destination"] as? String ?? "",
        routeShortName: args["routeShortName"] as? String ?? "",
        routeColor: args["routeColor"] as? String ?? "#B71C1C",
        cityId: args["cityId"] as? String ?? "")
      do {
        _ = try Activity.request(
          attributes: attrs,
          content: .init(state: state(from: args), staleDate: nil))
        return result(true)
      } catch {
        NSLog("live activity start failed: \(error.localizedDescription)")
        return result(false)
      }
    }
    #endif
    result(false)
  }

  private static func update(_ args: [String: Any], result: @escaping FlutterResult) {
    #if canImport(ActivityKit)
    if #available(iOS 16.2, *) {
      guard let activity = current else { return result(false) }
      let next = state(from: args)
      Task {
        await activity.update(.init(state: next, staleDate: Date().addingTimeInterval(300)))
        result(true)
      }
      return
    }
    #endif
    result(false)
  }

  private static func end(result: @escaping FlutterResult) {
    #if canImport(ActivityKit)
    if #available(iOS 16.2, *) {
      Task {
        await endAll()
        result(true)
      }
      return
    }
    #endif
    result(false)
  }

  #if canImport(ActivityKit)
  @available(iOS 16.2, *)
  private static func endAll() async {
    for a in Activity<OpenTransitActivityAttributes>.activities {
      await a.end(nil, dismissalPolicy: .immediate)
    }
  }
  #endif
}
