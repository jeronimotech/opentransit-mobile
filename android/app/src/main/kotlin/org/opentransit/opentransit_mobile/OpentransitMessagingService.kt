package org.opentransit.opentransit_mobile

import android.util.Log
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequest
import androidx.work.OutOfQuotaPolicy
import androidx.work.WorkManager
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import dev.fluttercommunity.workmanager.BackgroundWorker
import dev.fluttercommunity.workmanager.buildTaskInputData
import java.util.concurrent.TimeUnit

/**
 * Android half of the server pushes; `PushBridge.swift` is the iOS half. Written against the Firebase
 * Android SDK rather than the Flutter Firebase plugin on purpose: that plugin inserts itself into the
 * iOS notification delegate at launch even when Firebase is never configured there, and the iOS push
 * path already works.
 *
 * Both messages arrive data-only and neither is shown from here. They wake the Dart background isolate
 * the app already runs for scheduled trips — the same [BackgroundWorker] WorkManager uses — and Dart
 * does the rest:
 *
 *  * `tripRefresh` re-plans the trips leaving soon and re-arms their reminders;
 *  * `routeAlert` runs the followed-routes check, which is also what the fifteen-minute poll runs.
 *
 * Posting the notification from here instead would mean a second copy of the wording, in one language,
 * with its own idea of which alerts a rider has already seen. The push's job is to make that check
 * happen now rather than at the next poll, which on a phone whose vendor throttles background work is
 * the difference between knowing and not knowing.
 *
 * Nothing here is required. Without `google-services.json` Firebase never initialises, this service is
 * never called, and reminders keep running off the phone's own alarm.
 */
class OpentransitMessagingService : FirebaseMessagingService() {
    companion object {
        private const val TAG = "ot.push"

        /** Task names `tripRefreshDispatcher` (lib/core/scheduling/trip_scheduler.dart) understands. */
        private const val TASK_TRIP_REFRESH = "tripRefresh"
        private const val TASK_ROUTE_ALERTS = "routeAlertsPoll"
        private const val TASK_TOKEN_SYNC = "pushTokenSync"
    }

    /**
     * A new registration token. It cannot be sent from here — the server wants it alongside the wake
     * instants and followed routes that only Dart knows — so Dart is woken to register it.
     */
    override fun onNewToken(token: String) {
        Log.i(TAG, "FCM token minted or rotated; asking Dart to register it")
        enqueue(TASK_TOKEN_SYNC, mapOf("token" to token), unique = "push-token-sync")
    }

    override fun onMessageReceived(message: RemoteMessage) {
        when (val kind = message.data["kind"]) {
            "tripRefresh" -> enqueue(TASK_TRIP_REFRESH, emptyMap(), unique = "push-trip-refresh")
            "routeAlert" -> enqueue(TASK_ROUTE_ALERTS, emptyMap(), unique = "push-route-alerts")
            else -> Log.w(TAG, "ignoring push of unknown kind: $kind")
        }
    }

    /**
     * Runs a task in the Dart background isolate. Expedited so it starts now rather than whenever the
     * system feels like it — a wake-up that lands after the bus has gone is worse than none — falling
     * back to ordinary work once the app has spent its expedited quota. `REPLACE` because two pushes
     * arriving together want one check, not two.
     */
    private fun enqueue(task: String, payload: Map<String, Any?>, unique: String) {
        val request = OneTimeWorkRequest.Builder(BackgroundWorker::class.java)
            .setInputData(buildTaskInputData(task, payload))
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
            .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
            .setBackoffCriteria(BackoffPolicy.LINEAR, 30, TimeUnit.SECONDS)
            .addTag("opentransit-push")
            .build()
        WorkManager.getInstance(applicationContext)
            .enqueueUniqueWork(unique, ExistingWorkPolicy.REPLACE, request)
    }
}
