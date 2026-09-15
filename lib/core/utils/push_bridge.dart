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

/// Dart side of `opentransit/push` (iOS). The Runner hands over the APNs token and every silent
/// wake-up; the app registers the token and, on a wake-up, re-plans the trips due soon.
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
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      unawaited(_channel.invokeMethod<void>('register').catchError((Object e) {
        debugPrint('push register unavailable: $e');
      }));
    }
  }
}
