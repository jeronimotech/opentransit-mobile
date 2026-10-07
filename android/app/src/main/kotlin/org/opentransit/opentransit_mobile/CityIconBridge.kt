package org.opentransit.opentransit_mobile

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Swap the launcher icon between the nine city aliases declared in the manifest.
 *
 * Android has no API for "change my icon". It has enabling and disabling components, and the icon
 * follows whichever alias currently carries MAIN/LAUNCHER. Two rules keep that from going wrong:
 *
 * 1. **Enable the new one before disabling the old.** A moment with two icons is a cosmetic glitch;
 *    a moment with none leaves the app with no way back from the home screen.
 * 2. **Never touch MainActivity.** It carries the App Links, the geo: handler and the share target.
 *    Disabling it to hide an icon would quietly stop this app being offered for a map link, which
 *    is a real feature traded for a cosmetic one.
 *
 * [repair] exists because the failure here is not recoverable by the user: if every alias somehow
 * ends up disabled — a crash between the two calls, a restore of stale component state — the app is
 * gone from the launcher and only Settings can reopen it. Checking on startup costs one call.
 */
object CityIconBridge {
    private const val CHANNEL = "org.opentransit/city_icon"
    private const val DEFAULT = "Launcher"

    private val CITIES = listOf(
        "bogota", "boston", "brisbane", "casablanca", "kualalumpur",
        "lisboa", "roma", "santiago", "toronto",
    )

    /**
     * The namespace the manifest resolves `.Launcher…` against, which is NOT the application id.
     *
     * `namespace` is org.opentransit.opentransit_mobile and `applicationId` is
     * com.jeronimotech.opentransit, so `ComponentName(context, ".Launcher")` — which expands with
     * `context.packageName`, the application id — names a component that does not exist.
     * `setComponentEnabledSetting` throws for an unknown component, and since `repair` runs at
     * startup that is a crash on launch, for a cosmetic feature.
     *
     * Derived from a real class rather than written out, so it cannot drift if the namespace moves.
     */
    private val NAMESPACE: String = MainActivity::class.java.name.substringBeforeLast('.')

    private fun alias(context: Context, suffix: String) =
        ComponentName(context.packageName, "$NAMESPACE.$suffix")

    private fun aliasFor(city: String?): String =
        if (city != null && CITIES.contains(city)) {
            "Launcher" + city.replaceFirstChar { it.uppercase() }
        } else {
            DEFAULT
        }

    private fun all(): List<String> = listOf(DEFAULT) + CITIES.map { aliasFor(it) }

    private fun isEnabled(context: Context, suffix: String): Boolean =
        try {
            context.packageManager.getComponentEnabledSetting(alias(context, suffix)) ==
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        } catch (e: IllegalArgumentException) {
            false
        }

    /** The alias currently showing, or the default when the state says nothing. */
    private fun current(context: Context): String =
        all().firstOrNull { isEnabled(context, it) } ?: DEFAULT

    private fun setEnabled(context: Context, suffix: String, on: Boolean) {
        // Never fatal. This whole feature is a colour on a home screen, and the one thing it must
        // not do is take the app down with it.
        try {
            doSetEnabled(context, suffix, on)
        } catch (e: IllegalArgumentException) {
            // An alias this build does not declare. Nothing to enable, nothing to repair.
        }
    }

    private fun doSetEnabled(context: Context, suffix: String, on: Boolean) {
        context.packageManager.setComponentEnabledSetting(
            alias(context, suffix),
            if (on) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            // No DONT_KILL_APP: the launcher only notices the change when the package settings are
            // flushed, and keeping the process alive makes the old icon linger until a reboot.
            PackageManager.DONT_KILL_APP,
        )
    }

    /** Switch to [city]'s icon, or back to the default when it is null or unknown. */
    private fun select(context: Context, city: String?) {
        val wanted = aliasFor(city)
        val enabled = all().filter { isEnabled(context, it) }
        if (enabled == listOf(wanted)) return

        setEnabled(context, wanted, true)
        for (other in all()) {
            if (other != wanted && isEnabled(context, other)) setEnabled(context, other, false)
        }
    }

    /**
     * Put the default icon back if nothing is enabled.
     *
     * The only state this app cannot talk its way out of. Cheap to check, and the alternative is a
     * rider who has to find the app in Settings to open it again.
     */
    fun repair(context: Context) {
        if (all().none { isEnabled(context, it) }) setEnabled(context, DEFAULT, true)
    }

    fun register(messenger: BinaryMessenger, context: Context) {
        repair(context)
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "select" -> {
                    select(context, call.argument<String>("city"))
                    result.success(null)
                }
                "current" -> {
                    val now = current(context)
                    result.success(
                        if (now == DEFAULT) null
                        else CITIES.firstOrNull { aliasFor(it) == now },
                    )
                }
                else -> result.notImplemented()
            }
        }
    }
}
