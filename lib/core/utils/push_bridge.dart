import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/http_api_client.dart';
import '../config.dart';
import '../scheduling/push_registrar.dart';
import '../scheduling/trip_scheduler.dart';
import '../storage/scheduled_trips.dart';

/// Dart side of `opentransit/push`. iOS hands over the APNs token and every silent wake-up from
/// `PushBridge.swift`; Android hands over the FCM token from `PushTokenBridge.kt` and delivers its
/// wake-ups through the WorkManager isolate instead, because a push may arrive with no engine running.
/// Either way the app registers the token and, on a wake-up, re-plans the trips due soon.
class PushBridge {
  PushBridge._();
  static final instance = PushBridge._();
  static const _channel = MethodChannel('opentransit/push');

  /// Called after the token arrives or changes; the app re-registers.
  void Function(String token)? onToken;
  bool _installed = false;

  void install() {
    if (_installed) return;
    _installed = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onToken':
          final token = call.arguments?.toString() ?? '';
          if (token.isEmpty) return null;
          final prefs = await SharedPreferences.getInstance();
          await PushRegistrar(prefs: prefs, api: HttpApiClient(AppConfig.apiUrl))
              .saveToken(token, env: kReleaseMode ? 'prod' : 'sandbox');
          onToken?.call(token);
          return null;
        case 'refresh':
          // a silent push: plan the trips leaving soon with live data, adjust their reminders
          final prefs = await SharedPreferences.getInstance();
          final code = prefs.getString('locale');
          final scheduler = TripScheduler(
            repo: ScheduledTripsRepository(prefs),
            api: HttpApiClient(AppConfig.apiUrl),
            reminders: const LocalReminderSink(),
            jobs: const WorkmanagerJobs(),
            locale: Locale(code == null || code.isEmpty || code == 'system' ? 'es' : code),
          );
          final n = await scheduler.refreshDue(now: DateTime.now())
              .timeout(const Duration(seconds: 20), onTimeout: () => 0);
          return n;
        default:
          return null;
      }
    });
    // A build with no push credentials answers with an error, which is a normal state and not worth
    // more than a line in the log: the phone's own alarms are the floor either way.
    if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android) {
      unawaited(_channel.invokeMethod<void>('register').catchError((Object e) {
        debugPrint('push register unavailable: $e');
      }));
    }
  }
}
