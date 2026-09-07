package com.jeronimotech.opentransit.wear.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.items
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material.Chip
import androidx.wear.compose.material.ChipDefaults
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.jeronimotech.opentransit.wear.PhoneSnapshot
import com.jeronimotech.opentransit.wear.SnapshotStore
import com.jeronimotech.opentransit.wear.SummaryItem
import com.jeronimotech.opentransit.wear.WatchSummary

/**
 * *Cerca de ti*: the favourite stops the phone sent, each with its next
 * departures. The first screen and, for most riders, the only one they need.
 */
@Composable
fun NearbyScreen(
    snapshot: PhoneSnapshot?,
    summary: WatchSummary?,
    refreshing: Boolean,
    onStop: (String) -> Unit,
    onGo: () -> Unit,
) {
    val listState = rememberScalingLazyListState()

    ScreenScaffold {
        ScalingLazyColumn(
            state = listState,
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            item {
                Text(
                    text = snapshot?.cityName ?: "opentransit",
                    style = MaterialTheme.typography.title3,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }

            if (snapshot?.go?.active == true) {
                item {
                    Chip(
                        onClick = onGo,
                        colors = ChipDefaults.primaryChipColors(backgroundColor = BrandRed),
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text("Viaje en curso", maxLines = 1) },
                        secondaryLabel = snapshot.go.nextStopName?.let {
                            { Text(it, maxLines = 1, overflow = TextOverflow.Ellipsis) }
                        },
                    )
                }
            }

            val items = summary?.items.orEmpty()
            if (items.isEmpty()) {
                item { EmptyState(snapshot, refreshing, answered = summary != null) }
            } else {
                items(items, key = { it.stopId }) { item ->
                    StopRow(item = item, onClick = { onStop(item.stopId) })
                }
                item { FreshnessFooter(summary) }
            }
        }
    }
}

@Composable
private fun StopRow(item: SummaryItem, onClick: () -> Unit) {
    val first = item.routes.firstOrNull()
    Chip(
        onClick = onClick,
        colors = ChipDefaults.secondaryChipColors(),
        modifier = Modifier.fillMaxWidth(),
        label = {
            Text(
                text = item.stopName,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                style = MaterialTheme.typography.button,
            )
        },
        secondaryLabel = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (first != null) {
                    RouteChip(first.shortName, parseColor(first.color))
                    Spacer(Modifier.fillMaxWidth(0.04f))
                    Text(
                        text = departuresLabel(first),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        style = MaterialTheme.typography.caption2,
                    )
                } else {
                    Text("sin rutas", style = MaterialTheme.typography.caption2)
                }
            }
        },
    )
}

/**
 * What the watch says when it has nothing. Each case gets its own sentence:
 * "no data" is useless when the fix differs — open the phone app, or wait.
 */
@Composable
private fun EmptyState(snapshot: PhoneSnapshot?, refreshing: Boolean, answered: Boolean) {
    val message = when {
        snapshot == null ->
            "Abre opentransit en el teléfono para enviar tus favoritos"
        snapshot.favourites.isEmpty() ->
            "Guarda una parada favorita en el teléfono y aparecerá aquí"
        refreshing -> "Buscando salidas…"
        // The service answered and there is simply nothing running — at
        // midnight that is the truth, and calling it a connection failure
        // sends the rider to check their wifi for nothing.
        answered -> "Sin salidas ahora"
        else -> "Sin conexión con el servicio"
    }
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.padding(horizontal = 8.dp, vertical = 12.dp),
    ) {
        Text(
            text = message,
            textAlign = TextAlign.Center,
            style = MaterialTheme.typography.body2,
            color = Color.LightGray,
        )
    }
}

@Composable
private fun FreshnessFooter(summary: WatchSummary?) {
    val age = ageLabel(SnapshotStore.summaryAgeSeconds()) ?: return
    val live = summary?.realtime == true && summary.stale.not()
    Row(
        modifier = Modifier.padding(top = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        LiveDot(live)
        Spacer(Modifier.height(2.dp))
        Text(
            text = if (live) " en vivo · $age" else " $age",
            style = MaterialTheme.typography.caption3,
            color = Color.Gray,
            fontWeight = FontWeight.Normal,
        )
    }
}
