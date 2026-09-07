import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notifications for the follow-along ("Iniciar viaje") mode.
/// Foreground only; no push infrastructure.
class LocalNotifications {
  LocalNotifications._();
  static final instance = LocalNotifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<bool> init() async {
    if (_ready) return true;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
          settings: const InitializationSettings(android: android, iOS: ios));
      _ready = true;
    } catch (e) {
      debugPrint('notifications init failed: $e');
    }
    return _ready;
  }

  Future<bool> requestPermission() async {
    if (!await init()) return false;
    try {
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, sound: true) ?? false;
      }
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? true;
      }
    } catch (e) {
      debugPrint('notification permission failed: $e');
    }
    return true;
  }

  Future<void> show(int id, String title, String body) async {
    if (!await init()) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'trip', 'Viaje en curso',
            importance: Importance.high, priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
      );
    } catch (e) {
      debugPrint('notification show failed: $e');
    }
  }

  /// The persistent "trip in progress" notification. Android gets an ongoing,
  /// silent, low-priority entry with a progress bar; iOS has no equivalent, so
  /// it simply keeps the latest banner updated under the same id.
  static const ongoingId = 10;

  Future<void> showOngoing({
    required String title,
    required String body,
    int? progress,
    int? maxProgress,
  }) async {
    if (!await init()) return;
    try {
      final android = AndroidNotificationDetails(
        'trip_ongoing',
        'Viaje en curso',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        playSound: false,
        showProgress: progress != null && maxProgress != null,
        maxProgress: maxProgress ?? 0,
        progress: progress ?? 0,
      );
      await _plugin.show(
        id: ongoingId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: android,
          iOS: const DarwinNotificationDetails(
              presentAlert: false, presentSound: false, presentBanner: false),
        ),
      );
    } catch (e) {
      debugPrint('ongoing notification failed: $e');
    }
  }

  Future<void> cancelOngoing() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: ongoingId);
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
