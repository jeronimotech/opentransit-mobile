package com.jeronimotech.opentransit.wear

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.navigation.NavHostController
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.navigation.SwipeDismissableNavHost
import androidx.wear.compose.navigation.composable
import androidx.wear.compose.navigation.rememberSwipeDismissableNavController
import com.jeronimotech.opentransit.wear.screens.GoScreen
import com.jeronimotech.opentransit.wear.screens.LocateScreen
import com.jeronimotech.opentransit.wear.screens.NearbyScreen
import kotlinx.coroutines.delay

class WearMainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        SnapshotStore.load(this)
        seedFromIntentIfDebug()
        setContent { WearApp() }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        seedFromIntentIfDebug()
    }

    /**
     * Debug builds accept a snapshot over `adb`, which is the only way to
     * exercise the watch without a paired phone:
     *
     *   adb shell am start -n com.jeronimotech.opentransit/\
     *     com.jeronimotech.opentransit.wear.WearMainActivity \
     *     --es snapshot '{"cityId":"bogota",...}'
     *
     * Release builds ignore it entirely — the only source there is the phone.
     */
    private fun seedFromIntentIfDebug() {
        if (!BuildConfig.DEBUG) return
        val json = intent?.getStringExtra("snapshot") ?: return
        SnapshotStore.putSnapshot(this, json)
    }
}

object Routes {
    const val NEARBY = "nearby"
    const val LOCATE = "locate/{stopId}"
    const val GO = "go"
    fun locate(stopId: String) = "locate/$stopId"
}

@Composable
fun WearApp(navController: NavHostController? = null) {
    val nav = navController ?: rememberSwipeDismissableNavController()
    val snapshot by SnapshotStore.snapshot.collectAsState()
    val summary by SnapshotStore.summary.collectAsState()
    var refreshing by remember { mutableStateOf(false) }

    val context = androidx.compose.ui.platform.LocalContext.current

    // Refresh while the app is open. The board is only useful for a minute or
    // two, and the watch is only awake for about that long anyway.
    LaunchedEffect(snapshot?.cityId, snapshot?.favourites?.size) {
        val snap = snapshot ?: return@LaunchedEffect
        while (true) {
            refreshing = true
            WatchSummaryClient.fetch(context, snap)
            refreshing = false
            delay(30_000)
        }
    }

    // A trip in progress is the only thing worth showing unprompted.
    LaunchedEffect(snapshot?.go?.active) {
        if (snapshot?.go?.active == true) nav.navigate(Routes.GO)
    }

    MaterialTheme {
        SwipeDismissableNavHost(navController = nav, startDestination = Routes.NEARBY) {
            composable(Routes.NEARBY) {
                NearbyScreen(
                    snapshot = snapshot,
                    summary = summary,
                    refreshing = refreshing,
                    onStop = { nav.navigate(Routes.locate(it)) },
                    onGo = { nav.navigate(Routes.GO) },
                )
            }
            composable(Routes.LOCATE) { entry ->
                LocateScreen(
                    stopId = entry.arguments?.getString("stopId").orEmpty(),
                    summary = summary,
                    snapshot = snapshot,
                )
            }
            composable(Routes.GO) {
                GoScreen(go = snapshot?.go ?: GoState.idle)
            }
        }
    }
}
