import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Set by the screenshot walkthrough only, for the same reason as
/// [skipLocationPrompt] in `location.dart`: the iOS notification prompt is a
/// system alert that Dart cannot dismiss, and it would sit on top of every
/// screenshot taken from GO onwards. With this on the app never asks and
/// simply posts nothing if authorisation was never granted.
bool skipNotificationPrompt = false;

/// Local notifications for the follow-along ("Iniciar viaje") mode.
/// Foreground only; no push infrastructure.
class LocalNotifications {
  LocalNotifications._();
  static final instance = LocalNotifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _tzReady = false;

  /// App locations a tapped notification asks for (its `payload`), e.g.
  /// `/bogota/plan?fromLat=…&arriveBy=true`. The app routes them.
  final _taps = StreamController<String>.broadcast();
  Stream<String> get taps => _taps.stream;
  String? _launchPayload;

  /// The payload of the notification that launched the app, once.
  String? takeLaunchPayload() {
    final p = _launchPayload;
    _launchPayload = null;
    return p;
  }

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
        settings: const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: (r) {
          final p = r.payload;
          if (p != null && p.isNotEmpty) _taps.add(p);
        },
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        _launchPayload = launch!.notificationResponse?.payload;
      }
      _ready = true;
    } catch (e) {
      debugPrint('notifications init failed: $e');
    }
    return _ready;
  }

  /// Scheduled reminders need the device's zone: a 07:12 reminder is 07:12
  /// where the phone is, not UTC.
  Future<void> initTimezone() async {
    if (_tzReady) return;
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('timezone init failed (UTC assumed): $e');
    }
    _tzReady = true;
  }

  /// Android 12+ gates exact alarms behind a user setting; a "sal ahora"
  /// reminder that drifts ten minutes is useless, so the app asks once when
  /// the first trip is scheduled. Elsewhere this is a no-op.
  Future<void> requestExactAlarms() async {
    if (!await init()) return;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null && (await android.canScheduleExactNotifications()) != true) {
        await android.requestExactAlarmsPermission();
      }
    } catch (e) {
      debugPrint('exact alarm permission failed: $e');
    }
  }

  /// A one-shot reminder at [when] (local time). False when it could not be
  /// scheduled (no permission, the plugin failed, or [when] is already past).
  Future<bool> schedule(int id, String title, String body, DateTime when, {String? payload}) async {
    if (!await init()) return false;
    await initTimezone();
    if (!when.isAfter(DateTime.now())) return false;
    try {
      var exact = true;
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) exact = (await android.canScheduleExactNotifications()) ?? false;
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'trip_reminders', 'Viajes programados',
            importance: Importance.high, priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
        androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
      return true;
    } catch (e) {
      debugPrint('notification schedule failed: $e');
      return false;
    }
  }

  Future<void> cancel(int id) async {
    if (!await init()) return;
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}
  }

  /// Whether the OS will show our notifications at all. Null when it cannot be known (web, a failed
  /// plugin). iOS silently drops scheduled reminders when this is false — the one failure a rider
  /// cannot see, so the trips screen shows it.
  Future<bool?> permissionGranted() async {
    if (!await init()) return null;
    try {
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) return (await ios.checkPermissions())?.isEnabled;
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) return await android.areNotificationsEnabled();
    } catch (e) {
      debugPrint('notification permission check failed: $e');
    }
    return null;
  }

  /// Ids of the reminders the OS actually holds — what is really armed, as opposed to what we asked.
  Future<Set<int>> pendingIds() async {
    if (!await init()) return const {};
    try {
      return {for (final p in await _plugin.pendingNotificationRequests()) p.id};
    } catch (_) {
      return const {};
    }
  }

  /// An immediate reminder that opens [payload] when tapped.
  Future<void> showWithPayload(int id, String title, String body, {String? payload}) async {
    if (!await init()) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'trip_reminders', 'Viajes programados',
            importance: Importance.high, priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('notification show failed: $e');
    }
  }

  Future<bool> requestPermission() async {
    if (skipNotificationPrompt) return false;
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

  /// Android 16 promotes an ongoing notification with a progress style to a
  /// **Live Update** — the platform's answer to the Live Activity. When the
  /// native side takes it, it owns the notification (same id) and the plugin
  /// path is skipped, so the two can never both post.
  static const _liveUpdates = MethodChannel('opentransit/go_notification');
  bool? _liveUpdatesSupported;

  Future<bool> _liveUpdateAvailable() async {
    if (_liveUpdatesSupported != null) return _liveUpdatesSupported!;
    try {
      _liveUpdatesSupported =
          await _liveUpdates.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      _liveUpdatesSupported = false;
    } catch (_) {
      _liveUpdatesSupported = false;
    }
    return _liveUpdatesSupported!;
  }

  Future<void> showOngoing({
    required String title,
    required String body,
    int? progress,
    int? maxProgress,
  }) async {
    if (await _liveUpdateAvailable()) {
      try {
        final ok = await _liveUpdates.invokeMethod<bool>('show', {
              'title': title,
              'body': body,
              'progress': progress ?? 0,
              'maxProgress': maxProgress ?? 0,
            }) ??
            false;
        if (ok) return;
      } catch (e) {
        debugPrint('live update failed, using the plain notification: $e');
      }
    }
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
    // Cancel both owners: whichever posted it, the id is the same, and a
    // leftover "trip in progress" chip after arriving is the one bug a user
    // would never forgive.
    if (await _liveUpdateAvailable()) {
      try {
        await _liveUpdates.invokeMethod<bool>('cancel');
      } catch (_) {}
    }
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
