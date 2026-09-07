package com.jeronimotech.opentransit.wear.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.jeronimotech.opentransit.wear.RouteDepartures

/** Brand red, used when a route has no colour of its own. */
val BrandRed = Color(0xFFB71C1C)

/**
 * Feed colours are hex strings and occasionally nonsense; anything unparseable
 * falls back rather than throwing on a watch face.
 */
fun parseColor(hex: String?): Color {
    val raw = hex?.trim()?.removePrefix("#") ?: return BrandRed
    return try {
        when (raw.length) {
            6 -> Color(("ff$raw").toLong(16))
            8 -> Color(raw.toLong(16))
            else -> BrandRed
        }
    } catch (e: Throwable) {
        BrandRed
    }
}

/**
 * Pure black backgrounds are not a style choice on a watch: OLED pixels are
 * literally off, which is most of the battery saving.
 */
val WatchBackground = Color.Black

@Composable
fun RouteChip(shortName: String, color: Color, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(6.dp))
            .background(color)
            .padding(horizontal = 6.dp, vertical = 2.dp),
    ) {
        Text(
            text = shortName,
            style = MaterialTheme.typography.button,
            color = Color.White,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

/** "4 min · luego 12, 21" — the whole row a rider needs. */
fun departuresLabel(route: RouteDepartures): String {
    if (route.next.isEmpty()) return "sin datos"
    val first = route.next.first()
    val rest = route.next.drop(1).take(2).joinToString(", ") { it.minutes.toString() }
    val head = if (first.minutes <= 0) "ya" else "${first.minutes} min"
    return if (rest.isEmpty()) head else "$head · luego $rest"
}

/** "hace 40 s" / "hace 3 min" — what the watch is actually showing. */
fun ageLabel(seconds: Long?): String? = when {
    seconds == null -> null
    seconds < 45 -> "hace ${seconds.coerceAtLeast(0)} s"
    seconds < 3600 -> "hace ${seconds / 60} min"
    else -> "hace ${seconds / 3600} h"
}

@Composable
fun ScreenScaffold(content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            // Without fillMaxSize the box wraps its content and pins it to the
            // top, where a round bezel clips it. Centring only works once the
            // scaffold actually owns the screen.
            .fillMaxSize()
            .background(WatchBackground)
            .padding(PaddingValues(horizontal = 8.dp)),
        contentAlignment = Alignment.Center,
    ) { content() }
}

@Composable
fun LiveDot(realtime: Boolean) {
    Row {
        Text(
            text = if (realtime) "●" else "○",
            style = MaterialTheme.typography.caption3,
            color = if (realtime) Color(0xFF37AA2F) else Color.Gray,
        )
    }
}
