pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // AGP 8.7.3: compileSdk 35 + Firebase SDK 11 ile test edilmiş kararlı sürüm
    id("com.android.application") version "8.7.3" apply false
    // Kotlin 2.1.20: Compose Compiler dahil, Flutter 3.22+ uyumlu
    id("org.jetbrains.kotlin.android") version "2.1.20" apply false
    // Google Services 4.4.2: Firebase BOM 33.x (SDK 11) ile uyumlu
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
