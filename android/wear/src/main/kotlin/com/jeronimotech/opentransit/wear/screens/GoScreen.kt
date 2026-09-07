package com.jeronimotech.opentransit.wear.screens

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.jeronimotech.opentransit.wear.GoState
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * The GO mirror: next stop, minutes left, and the alert to get off.
 *
 * This is the screen that justifies a watch app at all. Looking at a phone to
 * know whether to stand up is exactly what you cannot do on a packed bus, so
 * the whole screen is one glanceable number and the alert is a tap on the
 * wrist.
 */
@Composable
fun GoScreen(go: GoState) {
    val context = LocalContext.current

    // Fires once per alight event, not on every recomposition: the phone sets
    // the flag and keeps it set, and a watch that buzzes repeatedly is a watch
    // people take off.
    LaunchedEffect(go.alight) {
        if (go.alight) vibrateAlight(context)
    }

    ScreenScaffold {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 10.dp),
        ) {
            if (!go.active) {
                Text(
                    text = "Sin viaje en curso",
                    style = MaterialTheme.typography.body2,
                    color = Color.LightGray,
                    textAlign = TextAlign.Center,
                )
                return@Column
            }

            go.routeShortName?.let {
                RouteChip(it, parseColor(go.routeColor))
                Spacer(Modifier.height(6.dp))
            }

            Text(
                text = go.minutesToNextStop?.let { if (it <= 0) "Ya" else "$it min" } ?: "—",
                style = MaterialTheme.typography.display2,
                color = if (go.alight) Color(0xFFFF9000) else Color.White,
            )

            go.nextStopName?.let {
                Text(
                    text = if (go.alight) "Bájate en $it" else it,
                    style = MaterialTheme.typography.body2,
                    textAlign = TextAlign.Center,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    color = if (go.alight) Color(0xFFFF9000) else Color.White,
                )
            }

            go.etaEpochSeconds?.let {
                Spacer(Modifier.height(4.dp))
                Text(
                    text = "llegas ${clock(it)}",
                    style = MaterialTheme.typography.caption2,
                    color = Color.Gray,
                )
            }
        }
    }
}

private fun clock(epochSeconds: Double): String =
    SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date((epochSeconds * 1000).toLong()))

/**
 * A double tap, long enough to feel through a sleeve. Guarded because
 * vibrator APIs differ by version and a missing one must never crash GO.
 */
private fun vibrateAlight(context: Context) {
    try {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        } ?: return
        vibrator.vibrate(
            VibrationEffect.createWaveform(longArrayOf(0, 220, 140, 220), -1)
        )
    } catch (e: Throwable) {
        // No vibrator, or permission denied on a stripped ROM.
    }
}
