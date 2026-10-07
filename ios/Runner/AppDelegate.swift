import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Scheduled-trip reminders: the opportunistic background refresh (BGAppRefresh) that re-plans a
    // trip with live data shortly before it is time to leave. Must be registered before launch ends.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.jeronimotech.opentransit.tripRefresh", earliestBeginInSeconds: NSNumber(value: 15 * 60))
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LiveActivityBridge") {
      LiveActivityBridge.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WatchSessionBridge") {
      WatchSessionBridge.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PushBridge") {
      PushBridge.register(with: registrar)
    }
    registerCityIconChannel(engineBridge.pluginRegistry.registrar(forPlugin: "CityIconBridge"))
  }

  // MARK: - Alternate app icons, one per city (v1.6)

  /// Deliberately here rather than in its own file: a new Swift file has to be added to the Xcode
  /// project, and a hand-edited `project.pbxproj` that nobody can build to check is a worse risk
  /// than a dozen lines living next to the other channel registrations.
  ///
  /// Nothing like Android's alias juggling is needed. `setAlternateIconName` is Apple's own API,
  /// a failure leaves the primary icon in place, and the names come from the asset catalog —
  /// `AppIcon-<city>`, listed in ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES. iOS shows the rider
  /// a confirmation alert on every change; that is Apple's, not ours, and cannot be suppressed.
  private func registerCityIconChannel(_ registrar: FlutterPluginRegistrar?) {
    guard let registrar else { return }
    let channel = FlutterMethodChannel(
      name: "org.opentransit/city_icon", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "current":
        // Nil means the primary icon, which is what "no city chosen" looks like.
        result(UIApplication.shared.alternateIconName.flatMap { name in
          name.hasPrefix("AppIcon-") ? String(name.dropFirst("AppIcon-".count)) : nil
        })
      case "select":
        guard UIApplication.shared.supportsAlternateIcons else {
          result(FlutterError(code: "unsupported",
                              message: "this device does not support alternate icons", details: nil))
          return
        }
        let city = (call.arguments as? [String: Any])?["city"] as? String
        let name = city.map { "AppIcon-\($0)" }
        DispatchQueue.main.async {
          UIApplication.shared.setAlternateIconName(name) { error in
            if let error {
              result(FlutterError(code: "failed", message: error.localizedDescription, details: nil))
            } else {
              result(nil)
            }
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - APNs (v2.3 scheduled-trip reminders)

  override func application(_ application: UIApplication,
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    PushBridge.tokenReceived(deviceToken)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(_ application: UIApplication,
                            didFailToRegisterForRemoteNotificationsWithError error: Error) {
    NSLog("APNs registration failed: %@", error.localizedDescription)
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  override func application(_ application: UIApplication,
                            didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                            fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    if PushBridge.handle(userInfo, completion: completionHandler) { return }
    super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
  }
}
