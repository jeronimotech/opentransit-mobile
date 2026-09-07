package com.jeronimotech.opentransit.wear

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * The watch's whole state: the last snapshot from the phone and the last
 * departure board, both persisted.
 *
 * Persisting matters more here than on the phone. A watch app is killed
 * constantly, and coming back to an empty screen when the phone is simply
 * asleep would make the app look broken. We show the last thing we knew,
 * labelled with its age, and refresh behind it.
 */
object SnapshotStore {
    private const val PREFS = "opentransit_wear"
    private const val KEY_SNAPSHOT = "snapshot_json"
    private const val KEY_SUMMARY = "summary_json"
    private const val KEY_SUMMARY_AT = "summary_at"

    private val _snapshot = MutableStateFlow<PhoneSnapshot?>(null)
    val snapshot: StateFlow<PhoneSnapshot?> = _snapshot

    private val _summary = MutableStateFlow<WatchSummary?>(null)
    val summary: StateFlow<WatchSummary?> = _summary

    private var loaded = false

    @Synchronized
    fun load(context: Context) {
        if (loaded) return
        loaded = true
        val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.getString(KEY_SNAPSHOT, null)?.let { _snapshot.value = PhoneSnapshot.parse(it) }
        prefs.getString(KEY_SUMMARY, null)?.let { json ->
            WatchSummary.parse(json)?.let {
                _summary.value = it.copy(fetchedAt = prefs.getLong(KEY_SUMMARY_AT, it.fetchedAt))
            }
        }
    }

    fun putSnapshot(context: Context, json: String) {
        val parsed = PhoneSnapshot.parse(json) ?: return
        _snapshot.value = parsed
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY_SNAPSHOT, json).apply()
    }

    fun putSummary(context: Context, summary: WatchSummary, json: String) {
        _summary.value = summary
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_SUMMARY, json)
            .putLong(KEY_SUMMARY_AT, summary.fetchedAt)
            .apply()
    }

    /** Whole seconds since the board we are showing was fetched. */
    fun summaryAgeSeconds(): Long? =
        _summary.value?.let { (System.currentTimeMillis() - it.fetchedAt) / 1000 }
}
