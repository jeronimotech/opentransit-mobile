// Wear OS companion. Deliberately NOT a dependency of :app — `flutter build
// apk` assembles the phone app alone, and this module is built and installed
// on its own (see README, "Wear OS"). The two only ever meet over the Data
// Layer, which pairs on the shared applicationId.
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.jeronimotech.opentransit.wear"
    compileSdk = 36

    defaultConfig {
        // Must match the phone app: Wear OS pairs a watch app to its phone app
        // by package name, and the Data Layer only talks within one package.
        applicationId = "com.jeronimotech.opentransit"
        // Wear OS 4.
        minSdk = 33
        targetSdk = 34
        versionCode = 10
        versionName = "1.8.0"
    }

    buildFeatures {
        compose = true
        // BuildConfig.DEBUG gates the adb snapshot seed in WearMainActivity.
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            // Debug keys keep `assembleRelease` working for local sideloading;
            // a store release would sign this the same way as the phone app.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")

    val composeBom = platform("androidx.compose:compose-bom:2024.10.01")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")

    // Wear-specific Compose: its own artefacts, not Material 3 for phones.
    implementation("androidx.wear.compose:compose-material:1.4.0")
    implementation("androidx.wear.compose:compose-foundation:1.4.0")
    implementation("androidx.wear.compose:compose-navigation:1.4.0")

    // Tiles.
    implementation("androidx.wear.tiles:tiles:1.4.1")
    implementation("androidx.wear.protolayout:protolayout:1.2.1")
    implementation("androidx.wear.protolayout:protolayout-material:1.2.1")
    implementation("androidx.wear.protolayout:protolayout-expression:1.2.1")
    implementation("com.google.guava:guava:33.7.1-android")

    // Ongoing activity: the trip chip on the watch face.
    implementation("androidx.wear:wear-ongoing:1.0.0")

    // The link to the phone.
    implementation("com.google.android.gms:play-services-wearable:18.2.0")
}
