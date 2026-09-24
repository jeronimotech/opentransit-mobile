package org.opentransit.opentransit_mobile

import android.content.Context
import android.util.Log
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Android half of `opentransit/push`, the same channel `PushBridge.swift` answers on iOS, so the Dart
 * side asks one question ("register me") and does not care which service replies.
 *
 * [OpentransitMessagingService.onNewToken] only fires when the token is minted or rotated, so on every
 * other launch the current one has to be asked for — otherwise a phone that registered once and then
 * had its app data cleared would never register again.
 */
object PushTokenBridge {
    private const val TAG = "ot.push"
    private const val CHANNEL = "opentransit/push"

    fun register(messenger: BinaryMessenger, context: Context) {
        val channel = MethodChannel(messenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "register" -> sendToken(channel, context, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun sendToken(channel: MethodChannel, context: Context, result: MethodChannel.Result) {
        // No google-services.json means no default Firebase app, which is a normal build rather than a
        // failure: Dart logs it and the phone keeps running its reminders off its own alarm.
        if (FirebaseApp.getApps(context).isEmpty()) {
            result.error("no-firebase", "Firebase is not configured in this build", null)
            return
        }
        FirebaseMessaging.getInstance().token
            .addOnSuccessListener { token ->
                channel.invokeMethod("onToken", token)
                result.success(null)
            }
            .addOnFailureListener { e ->
                Log.w(TAG, "FCM token unavailable: ${e.message}")
                result.error("no-token", e.message, null)
            }
    }
}
