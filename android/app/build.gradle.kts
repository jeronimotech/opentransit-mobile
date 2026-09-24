import java.util.Properties

// Signing material lives outside the repository (android/key.properties is gitignored
// and points at a keystore elsewhere on disk). Absent, release builds fall back to the
// debug key so the project still builds for everyone else.
val keystoreProperties: Properties? = rootProject.file("key.properties").takeIf { it.exists() }?.let { f ->
    Properties().apply { f.inputStream().use { load(it) } }
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Server pushes are optional. The google-services plugin fails the build outright when
// google-services.json is missing, so it is applied only when the file is actually there:
// a clone without Firebase credentials still builds and runs, it just never gets a push.
val firebaseConfig = file("google-services.json")
if (firebaseConfig.exists()) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "org.opentransit.opentransit_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications needs java.time on older API levels.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.jeronimotech.opentransit"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Release signing is deliberately optional. The keystore never lives in the
        // repository, so CI and anyone who clones this can still build a release APK
        // (unsigned by Play's standards, signed with the debug key) while a real
        // upload build requires android/key.properties to exist and point at it.
        if (keystoreProperties != null) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystoreProperties != null) {
                signingConfigs.getByName("release")
            } else {
                // Debug keys: Play rejects these, which is the point — a build made
                // without the keystore must not look publishable.
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // Firebase Cloud Messaging, the Android half of the scheduled-trip pushes. The BoM keeps the
    // Firebase libraries on one consistent set of versions.
    implementation(platform("com.google.firebase:firebase-bom:34.1.0"))
    implementation("com.google.firebase:firebase-messaging")
    // The push service hands `tripRefresh` to the same Dart isolate WorkManager already runs.
    // The workmanager plugin keeps this as `implementation`, so it is not on our classpath through it.
    implementation("androidx.work:work-runtime:2.11.2")
    // Phone half of the watch link (WatchDataLayerBridge). Degrades to "no
    // watch" on devices without Play Services rather than failing to start.
    implementation("com.google.android.gms:play-services-wearable:18.2.0")
}
