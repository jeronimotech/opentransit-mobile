package com.jeronimotech.opentransit.wear.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.items
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.jeronimotech.opentransit.wear.PhoneSnapshot
import com.jeronimotech.opentransit.wear.RouteDepartures
import com.jeronimotech.opentransit.wear.SnapshotStore
import com.jeronimotech.opentransit.wear.WatchSummary

/**
 * *Ubica tu bus*: every route serving one saved stop, with its next
 * departures. The phone screen of the same name draws a map; a watch cannot
 * usefully do that, so this keeps the part that answers the question — how
 * long until my bus.
 */
@Composable
fun LocateScreen(stopId: String, summary: WatchSummary?, snapshot: PhoneSnapshot?) {
    val item = summary?.items?.firstOrNull { it.stopId == stopId }
    val listState = rememberScalingLazyListState()

    ScreenScaffold {
        ScalingLazyColumn(
            state = listState,
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            item {
                Text(
                    text = item?.stopName
                        ?: snapshot?.favourites?.firstOrNull { it.id == stopId }?.label
                        ?: "Parada",
                    style = MaterialTheme.typography.title3,
                    textAlign = TextAlign.Center,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }

            val routes = item?.routes.orEmpty()
            if (routes.isEmpty()) {
                item {
                    Text(
                        text = "Sin salidas ahora",
                        style = MaterialTheme.typography.body2,
                        color = Color.LightGray,
                        modifier = Modifier.padding(vertical = 12.dp),
                    )
                }
            } else {
                items(routes, key = { it.routeId }) { RouteRow(it) }
                item {
                    val age = ageLabel(SnapshotStore.summaryAgeSeconds())
                    if (age != null) {
                        Text(
                            text = age,
                            style = MaterialTheme.typography.caption3,
                            color = Color.Gray,
                            textAlign = TextAlign.Center,
                            // A wrapped item lands wherever its content ends;
                            // the footer has to own the row to sit centred.
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(top = 4.dp),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun RouteRow(route: RouteDepartures) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        RouteChip(route.shortName, parseColor(route.color))
        Spacer(Modifier.width(6.dp))
        Column(Modifier.fillMaxWidth()) {
            Text(
                text = departuresLabel(route),
                style = MaterialTheme.typography.body2,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            val live = route.next.firstOrNull()?.realtime == true
            Text(
                text = if (live) "en vivo" else "programado",
                style = MaterialTheme.typography.caption3,
                color = if (live) Color(0xFF37AA2F) else Color.Gray,
            )
        }
    }
}
