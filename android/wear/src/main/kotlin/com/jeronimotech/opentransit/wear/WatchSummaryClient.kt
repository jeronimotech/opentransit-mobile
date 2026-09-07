package com.jeronimotech.opentransit.wear

import android.content.Context
import android.net.Uri
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.URL

/**
 * The offline fallback: the watch asks the API directly when the phone is out
 * of range.
 *
 * `GET /v1/cities/{city}/watch/summary` is built for exactly this — a couple of
 * kilobytes, names already truncated for a watch face, no geometry. Plain
 * HttpURLConnection keeps the watch APK small; there is one request in the
 * whole app.
 */
object WatchSummaryClient {
    private const val TAG = "WatchSummary"
    private const val TIMEOUT_MS = 8_000

    /**
     * Fetches the board for [snapshot]'s favourites. Returns null on any
     * failure; the caller keeps showing the cached board with its age, which
     * beats an error screen on a watch.
     */
    suspend fun fetch(context: Context, snapshot: PhoneSnapshot): WatchSummary? =
        withContext(Dispatchers.IO) {
            val base = snapshot.apiBaseUrl.trimEnd('/')
            if (base.isEmpty()) return@withContext null

            val stops = snapshot.favourites.filter { it.kind == "stop" }.map { it.id }
            val routes = snapshot.favourites.mapNotNull { it.routeId }
            val url = Uri.parse("$base/v1/cities/${snapshot.cityId}/watch/summary")
                .buildUpon()
                .apply {
                    if (stops.isNotEmpty()) appendQueryParameter("stops", stops.joinToString(","))
                    if (routes.isNotEmpty()) appendQueryParameter("routes", routes.joinToString(","))
                    appendQueryParameter("limit", "3")
                }
                .build().toString()

            var conn: HttpURLConnection? = null
            try {
                conn = (URL(url).openConnection() as HttpURLConnection).apply {
                    requestMethod = "GET"
                    connectTimeout = TIMEOUT_MS
                    readTimeout = TIMEOUT_MS
                    setRequestProperty("Accept", "application/json")
                }
                if (conn.responseCode !in 200..299) {
                    Log.w(TAG, "summary HTTP ${conn.responseCode}")
                    return@withContext null
                }
                val body = conn.inputStream.bufferedReader().use { it.readText() }
                val parsed = WatchSummary.parse(body) ?: return@withContext null
                SnapshotStore.putSummary(context, parsed, body)
                parsed
            } catch (e: Throwable) {
                Log.w(TAG, "summary fetch failed: ${e.message}")
                null
            } finally {
                conn?.disconnect()
            }
        }
}
