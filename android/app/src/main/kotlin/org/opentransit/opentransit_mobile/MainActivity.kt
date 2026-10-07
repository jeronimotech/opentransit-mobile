package org.opentransit.opentransit_mobile

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    /**
     * Turn a share into a deep link.
     *
     * Flutter's own deep-link plumbing only understands ACTION_VIEW with a data URI, so a share
     * (ACTION_SEND, text in an extra) would otherwise need a second platform channel and its own
     * lifecycle handling. Rewriting the intent before Flutter reads it means the shared text
     * arrives through the path `opentransit://…` links already take, and all the parsing stays in
     * Dart where it is tested.
     *
     * The text is passed through untouched: deciding whether it is a geo: URI, a map link, a
     * coordinate pair or nothing at all is `parseSharedLocation`'s job, not this file's.
     */
    private fun rewriteShareIntent(intent: Intent?) {
        if (intent == null || intent.action != Intent.ACTION_SEND) return
        val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return
        intent.action = Intent.ACTION_VIEW
        intent.data = Uri.parse("opentransit://shared")
            .buildUpon()
            .appendQueryParameter("text", text)
            .build()
        // Leaving the extra behind would hand the same payload to anything else reading the intent.
        intent.removeExtra(Intent.EXTRA_TEXT)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Before super: FlutterActivity reads the intent on the way up to decide the initial route.
        rewriteShareIntent(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        // A share arriving while the app is already running.
        rewriteShareIntent(intent)
        super.onNewIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        WatchDataLayerBridge.register(messenger, applicationContext)
        GoNotificationBridge.register(messenger, applicationContext)
        PushTokenBridge.register(messenger, applicationContext)
    }
}
