import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'core/providers.dart';
import 'core/scheduling/trip_scheduler.dart';
import 'core/utils/notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // Scheduled-trip reminders: the tap handler must exist before the first frame so a notification
  // that launched the app is not lost, and the background refresh needs its dispatcher registered.
  await LocalNotifications.instance.init();
  if (!kIsWeb) {
    try {
      await Workmanager().initialize(tripRefreshDispatcher);
    } catch (e) {
      debugPrint('workmanager unavailable: $e');
    }
  }
  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const OpenTransitApp(),
    ),
  );
}
