package com.jeronimotech.opentransit.wear

import org.json.JSONArray
import org.json.JSONObject

/**
 * The phone's snapshot and the API's departure board, as the watch needs them.
 *
 * Everything here is decoded **leniently**: a missing or unexpected field
 * yields a default, never an exception. On watchOS the strict, synthesised
 * decoder blanked the whole screen when one field was absent — the same
 * mistake is easy to make here and much harder to notice, because a watch
 * showing nothing looks like a watch that is simply out of range.
 */

private fun JSONObject.str(key: String): String? =
    if (isNull(key)) null else optString(key, "").ifEmpty { null }

private fun JSONObject.intOrNull(key: String): Int? =
    if (has(key) && !isNull(key)) optInt(key, Int.MIN_VALUE).takeIf { it != Int.MIN_VALUE } else null

private fun JSONObject.dblOrNull(key: String): Double? =
    if (has(key) && !isNull(key)) optDouble(key, Double.NaN).takeIf { !it.isNaN() } else null

private inline fun <T> JSONArray?.map(transform: (JSONObject) -> T?): List<T> {
    if (this == null) return emptyList()
    val out = ArrayList<T>(length())
    for (i in 0 until length()) {
        optJSONObject(i)?.let { transform(it)?.let(out::add) }
    }
    return out
}

data class Favourite(
    val kind: String,
    val id: String,
    val label: String,
    val routeId: String? = null,
    val color: String? = null,
    val lat: Double? = null,
    val lon: Double? = null,
) {
    companion object {
        fun from(o: JSONObject): Favourite? {
            val id = o.str("id") ?: return null
            return Favourite(
                kind = o.str("kind") ?: "stop",
                id = id,
                label = o.str("label") ?: id,
                routeId = o.str("routeId"),
                color = o.str("color"),
                lat = o.dblOrNull("lat"),
                lon = o.dblOrNull("lon"),
            )
        }
    }
}

data class GoState(
    val active: Boolean = false,
    val nextStopName: String? = null,
    val minutesToNextStop: Int? = null,
    val routeShortName: String? = null,
    val routeColor: String? = null,
    val etaEpochSeconds: Double? = null,
    val alight: Boolean = false,
) {
    companion object {
        val idle = GoState()

        fun from(o: JSONObject?): GoState {
            if (o == null) return idle
            return GoState(
                active = o.optBoolean("active", false),
                nextStopName = o.str("nextStopName"),
                minutesToNextStop = o.intOrNull("minutesToNextStop"),
                routeShortName = o.str("routeShortName"),
                routeColor = o.str("routeColor"),
                etaEpochSeconds = o.dblOrNull("etaEpochSeconds"),
                alight = o.optBoolean("alight", false),
            )
        }
    }
}

/** What the phone last told us. */
data class PhoneSnapshot(
    val cityId: String,
    val cityName: String,
    val apiBaseUrl: String,
    val favourites: List<Favourite>,
    val go: GoState,
    val analyticsEnabled: Boolean,
    val sentAtEpochSeconds: Double?,
) {
    val pinned: Favourite? get() = favourites.firstOrNull()

    companion object {
        fun parse(json: String): PhoneSnapshot? = try {
            val o = JSONObject(json)
            val city = o.str("cityId") ?: return null
            PhoneSnapshot(
                cityId = city,
                cityName = o.str("cityName") ?: city,
                apiBaseUrl = o.str("apiBaseUrl").orEmpty(),
                favourites = o.optJSONArray("favourites").map(Favourite::from),
                go = GoState.from(o.optJSONObject("go")),
                analyticsEnabled = o.optBoolean("analyticsEnabled", true),
                sentAtEpochSeconds = o.dblOrNull("sentAt"),
            )
        } catch (e: Throwable) {
            null
        }
    }
}

// ---------------------------------------------------------------- departures

data class NextDeparture(val minutes: Int, val realtime: Boolean) {
    companion object {
        fun from(o: JSONObject): NextDeparture? {
            val m = o.intOrNull("minutes") ?: return null
            return NextDeparture(m, o.optBoolean("realtime", false))
        }
    }
}

data class RouteDepartures(
    val routeId: String,
    val shortName: String,
    val color: String?,
    val next: List<NextDeparture>,
) {
    companion object {
        fun from(o: JSONObject): RouteDepartures? {
            val id = o.str("routeId") ?: return null
            return RouteDepartures(
                routeId = id,
                shortName = o.str("shortName") ?: "?",
                color = o.str("color"),
                next = o.optJSONArray("next").map(NextDeparture::from),
            )
        }
    }
}

data class SummaryItem(
    val kind: String,
    val stopId: String,
    val stopName: String,
    val component: String?,
    val distanceMeters: Int?,
    val routes: List<RouteDepartures>,
) {
    companion object {
        fun from(o: JSONObject): SummaryItem? {
            val id = o.str("stopId") ?: return null
            return SummaryItem(
                kind = o.str("kind") ?: "stop",
                stopId = id,
                stopName = o.str("stopName") ?: id,
                component = o.str("component"),
                distanceMeters = o.intOrNull("distanceMeters"),
                routes = o.optJSONArray("routes").map(RouteDepartures::from),
            )
        }
    }
}

/**
 * `GET /v1/cities/{city}/watch/summary`. [fetchedAt] is ours, not the API's:
 * the watch shows the age of what it holds, which is the only honest thing to
 * show when the radio has been off.
 */
data class WatchSummary(
    val items: List<SummaryItem>,
    val realtime: Boolean,
    val stale: Boolean,
    val alerts: Int,
    val fetchedAt: Long = System.currentTimeMillis(),
) {
    companion object {
        fun parse(json: String): WatchSummary? = try {
            val o = JSONObject(json)
            val fresh = o.optJSONObject("freshness")
            WatchSummary(
                items = o.optJSONArray("items").map(SummaryItem::from),
                realtime = fresh?.optBoolean("realtime", false) ?: false,
                stale = fresh?.optBoolean("stale", false) ?: false,
                alerts = o.intOrNull("alerts") ?: 0,
            )
        } catch (e: Throwable) {
            null
        }
    }
}
