package com.jeronimotech.opentransit.wear

import androidx.wear.tiles.TileService
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.WearableListenerService
import com.jeronimotech.opentransit.wear.tile.DeparturesTileService

/**
 * Receives the phone's snapshot over the Data Layer.
 *
 * The phone writes one data item at [PATH] whose payload is the same JSON the
 * iOS side sends as an application context, so the two platforms share a wire
 * format and this service stays a few lines long.
 */
class PhoneSnapshotListenerService : WearableListenerService() {

    companion object {
        /** Mirrors WatchDataLayerBridge.PATH on the phone. */
        const val PATH = "/opentransit/snapshot"
    }

    override fun onDataChanged(events: DataEventBuffer) {
        var changed = false
        for (event in events) {
            if (event.type != DataEvent.TYPE_CHANGED) continue
            val item = event.dataItem
            if (item.uri.path != PATH) continue
            val json = item.data?.toString(Charsets.UTF_8) ?: continue
            SnapshotStore.load(this)
            SnapshotStore.putSnapshot(this, json)
            changed = true
        }
        // A new pinned stop or a trip starting should show on the tile without
        // waiting for its own refresh window.
        if (changed) {
            runCatching { TileService.getUpdater(this).requestUpdate(DeparturesTileService::class.java) }
        }
    }
}
