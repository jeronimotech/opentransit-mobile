package org.opentransit.opentransit_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        WatchDataLayerBridge.register(messenger, applicationContext)
        GoNotificationBridge.register(messenger, applicationContext)
    }
}
