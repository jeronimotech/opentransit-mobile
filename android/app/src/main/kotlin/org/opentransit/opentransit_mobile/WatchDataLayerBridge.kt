package org.opentransit.opentransit_mobile

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.PutDataRequest
import com.google.android.gms.wearable.Wearable
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * Phone half of the watch link on Android: pushes city, favourites and GO
 * state to the paired Wear OS device.
 *
 * A Data Layer *data item* (not a message) is deliberate, and mirrors what
 * WatchSessionBridge.swift does with an application context: it survives the
 * watch being asleep and only the latest snapshot matters — a departure board
 * from three minutes ago is worse than none.
 *
 * The whole snapshot travels as one JSON string rather than a typed DataMap.
 * The wire format is then identical on both platforms, and the watch can
 * decode it leniently; a DataMap would make every added field a two-sided
 * migration.
 */
class WatchDataLayerBridge(private val context: Context) {

    companion object {
        const val CHANNEL = "opentransit/watch"

        /** Also hardcoded in the wear module: keep the two in step. */
        const val PATH = "/opentransit/snapshot"
        const val KEY_JSON = "json"
        private const val TAG = "WatchBridge"

        fun register(messenger: BinaryMessenger, context: Context) {
            val bridge = WatchDataLayerBridge(context.applicationContext)
            MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(bridge.isSupported())
                    "isPaired" -> result.success(bridge.isPaired())
                    "sync" -> result.success(
                        bridge.send(call.arguments as? Map<*, *> ?: emptyMap<String, Any?>())
                    )
                    else -> result.notImplemented()
                }
            }
        }

        /**
         * Flutter hands over nested maps and lists; org.json needs them wrapped.
         * Written out rather than trusting JSONObject(Map), whose recursive
         * wrapping has differed between Android versions.
         */
        fun toJson(value: Any?): Any = when (value) {
            null -> JSONObject.NULL
            is Map<*, *> -> JSONObject().apply {
                value.forEach { (k, v) -> if (k is String) put(k, toJson(v)) }
            }
            is Iterable<*> -> JSONArray().apply { value.forEach { put(toJson(it)) } }
            else -> value
        }
    }

    private val client: DataClient? by lazy {
        try {
            Wearable.getDataClient(context)
        } catch (e: Throwable) {
            // No Play Services (an emulator image without them, a de-Googled
            // ROM): the watch link simply does not exist, which is not an error.
            Log.i(TAG, "wearable data layer unavailable: ${e.message}")
            null
        }
    }

    fun isSupported(): Boolean = client != null

    /**
     * True only when a watch is actually connected. Node discovery is async,
     * so this is a best-effort read of the last known set: callers treat false
     * as "no watch", never as a failure.
     */
    fun isPaired(): Boolean {
        val c = client ?: return false
        return try {
            val nodes = Wearable.getNodeClient(context).connectedNodes
            // A short wait: this runs on a platform-channel call, and the Data
            // Layer answers from a local cache when the watch is known.
            val result = com.google.android.gms.tasks.Tasks.await(
                nodes, 1500, java.util.concurrent.TimeUnit.MILLISECONDS
            )
            c.let { result.isNotEmpty() }
        } catch (e: Throwable) {
            false
        }
    }

    /**
     * Replaces the watch's snapshot. Returns false when there is nothing to
     * talk to, which the Dart side treats as "not an error, just no watch".
     */
    fun send(payload: Map<*, *>): Boolean {
        val c = client ?: return false
        return try {
            val json = (toJson(payload) as JSONObject).apply {
                put("sentAt", System.currentTimeMillis() / 1000.0)
            }
            val request = PutDataRequest.create(PATH).apply {
                data = json.toString().toByteArray(Charsets.UTF_8)
                // Deliver now: a trip in progress cannot wait for the batching
                // window, which is measured in tens of minutes.
                setUrgent()
            }
            c.putDataItem(request)
            true
        } catch (e: Throwable) {
            Log.w(TAG, "watch sync failed: ${e.message}")
            false
        }
    }
}
