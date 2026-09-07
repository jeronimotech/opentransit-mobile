package com.jeronimotech.opentransit.wear.tile

import androidx.wear.protolayout.ColorBuilders.argb
import androidx.wear.protolayout.LayoutElementBuilders
import androidx.wear.protolayout.ResourceBuilders
import androidx.wear.protolayout.TimelineBuilders
import androidx.wear.protolayout.material.Colors
import androidx.wear.protolayout.material.Text
import androidx.wear.protolayout.material.Typography
import androidx.wear.protolayout.material.layouts.PrimaryLayout
import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.TileBuilders
import androidx.wear.tiles.TileService
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import com.jeronimotech.opentransit.wear.SnapshotStore
import com.jeronimotech.opentransit.wear.screens.departuresLabel

/**
 * The tile: the pinned stop's next departures, one swipe from the watch face.
 *
 * A tile cannot fetch on its own schedule cheaply, so it renders whatever the
 * app and the phone last stored and asks the system to come back in a minute.
 * Showing a slightly old number with its age beats showing nothing.
 */
class DeparturesTileService : TileService() {

    companion object {
        private const val RESOURCES_VERSION = "1"
        private const val REFRESH_MILLIS = 60_000L
    }

    override fun onTileResourcesRequest(
        requestParams: RequestBuilders.ResourcesRequest
    ): ListenableFuture<ResourceBuilders.Resources> = Futures.immediateFuture(
        ResourceBuilders.Resources.Builder().setVersion(RESOURCES_VERSION).build()
    )

    override fun onTileRequest(
        requestParams: RequestBuilders.TileRequest
    ): ListenableFuture<TileBuilders.Tile> {
        SnapshotStore.load(this)
        val summary = SnapshotStore.summary.value
        val snapshot = SnapshotStore.snapshot.value
        val item = summary?.items?.firstOrNull()
        val route = item?.routes?.firstOrNull()

        val title = item?.stopName ?: snapshot?.pinned?.label ?: "opentransit"
        val body = when {
            route != null -> "${route.shortName} · ${departuresLabel(route)}"
            snapshot == null -> "Abre la app en el teléfono"
            else -> "Sin salidas"
        }

        val layout = PrimaryLayout.Builder(requestParams.deviceConfiguration)
            .setResponsiveContentInsetEnabled(true)
            .setPrimaryLabelTextContent(
                Text.Builder(this, title)
                    .setTypography(Typography.TYPOGRAPHY_CAPTION1)
                    .setColor(argb(Colors.DEFAULT.onSurface))
                    .setMaxLines(1)
                    .build()
            )
            .setContent(
                Text.Builder(this, body)
                    .setTypography(Typography.TYPOGRAPHY_TITLE3)
                    .setColor(argb(Colors.DEFAULT.onSurface))
                    .setMaxLines(2)
                    .build()
            )
            .apply {
                ageFooter()?.let {
                    setSecondaryLabelTextContent(
                        Text.Builder(this@DeparturesTileService, it)
                            .setTypography(Typography.TYPOGRAPHY_CAPTION2)
                            .setColor(argb(Colors.DEFAULT.onSurface))
                            .setMaxLines(1)
                            .build()
                    )
                }
            }
            .build()

        return Futures.immediateFuture(
            TileBuilders.Tile.Builder()
                .setResourcesVersion(RESOURCES_VERSION)
                .setFreshnessIntervalMillis(REFRESH_MILLIS)
                .setTileTimeline(
                    TimelineBuilders.Timeline.Builder()
                        .addTimelineEntry(
                            TimelineBuilders.TimelineEntry.Builder()
                                .setLayout(
                                    LayoutElementBuilders.Layout.Builder()
                                        .setRoot(layout)
                                        .build()
                                )
                                .build()
                        )
                        .build()
                )
                .build()
        )
    }

    private fun ageFooter(): String? =
        com.jeronimotech.opentransit.wear.screens.ageLabel(SnapshotStore.summaryAgeSeconds())
}
