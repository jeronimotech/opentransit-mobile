package org.opentransit.opentransit_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * The Android answer to the iOS Live Activity.
 *
 * Android 16 (API 36) promotes an ongoing notification with a
 * [Notification.ProgressStyle] to a **Live Update**: a compact, always-visible
 * chip on the lock screen and status bar, which is the closest thing the
 * platform has to the Dynamic Island.
 *
 * Below API 36 this reports `false` and Dart keeps using the plain ongoing
 * notification from flutter_local_notifications. Exactly one of the two owns
 * the notification at any moment — they deliberately share [NOTIFICATION_ID]
 * so a stale one can never linger beside the other.
 */
class GoNotificationBridge(private val context: Context) {

    companion object {
        const val CHANNEL = "opentransit/go_notification"

        /** Same id flutter_local_notifications uses for the ongoing entry. */
        const val NOTIFICATION_ID = 10
        private const val CHANNEL_ID = "trip_ongoing"
        private const val TAG = "GoNotification"

        fun register(messenger: BinaryMessenger, context: Context) {
            val bridge = GoNotificationBridge(context.applicationContext)
            MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(bridge.isSupported)
                    "show" -> result.success(
                        bridge.show(
                            title = call.argument<String>("title").orEmpty(),
                            body = call.argument<String>("body").orEmpty(),
                            progress = call.argument<Int>("progress") ?: 0,
                            maxProgress = call.argument<Int>("maxProgress") ?: 0,
                        )
                    )
                    "cancel" -> result.success(bridge.cancel())
                    else -> result.notImplemented()
                }
            }
        }
    }

    /** Live Updates exist only from Android 16. */
    val isSupported: Boolean get() = Build.VERSION.SDK_INT >= 36

    private fun canPost(): Boolean =
        Build.VERSION.SDK_INT < 33 ||
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    private fun ensureChannel() {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Viaje en curso", NotificationManager.IMPORTANCE_LOW)
                .apply { setShowBadge(false) }
        )
    }

    fun show(title: String, body: String, progress: Int, maxProgress: Int): Boolean {
        if (!isSupported || !canPost()) return false
        return try {
            ensureChannel()
            val builder = Notification.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_menu_directions)
                .setContentTitle(title)
                .setContentText(body)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setCategory(Notification.CATEGORY_NAVIGATION)

            // ProgressStyle is what makes this a Live Update and it exists in
            // API 36, which is what Flutter compiles against.
            val style = Notification.ProgressStyle()
                .setProgress(progress.coerceAtLeast(0))
                .setProgressSegments(
                    listOf(Notification.ProgressStyle.Segment(maxProgress.coerceAtLeast(1)))
                )
            builder.setStyle(style)
            requestPromotion(builder)

            NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, builder.build())
            true
        } catch (e: Throwable) {
            // A vendor ROM that reports API 36 without the API, or a revoked
            // permission: fall back rather than lose the trip notification.
            Log.w(TAG, "live update failed, falling back: ${e.message}")
            false
        }
    }

    /**
     * Asks the system to promote the notification to the lock screen.
     *
     * `setRequestPromotedOngoing` landed in **API 36.1**, while Flutter pins
     * `compileSdk` to 36, so this cannot be a direct call without dragging the
     * whole app to a newer platform for one optional flag. Reflection keeps the
     * app compiling against Flutter's default and simply does nothing on the
     * devices that lack the method — which is exactly the intended behaviour,
     * since the notification is already correct without the promotion.
     */
    private fun requestPromotion(builder: Notification.Builder) {
        try {
            Notification.Builder::class.java
                .getMethod("setRequestPromotedOngoing", Boolean::class.javaPrimitiveType)
                .invoke(builder, true)
        } catch (e: NoSuchMethodException) {
            // Android 16.0: Live Update styling without the lock-screen chip.
        } catch (e: Throwable) {
            Log.i(TAG, "promotion request unavailable: ${e.message}")
        }
    }

    fun cancel(): Boolean {
        return try {
            NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
            true
        } catch (e: Throwable) {
            false
        }
    }
}
