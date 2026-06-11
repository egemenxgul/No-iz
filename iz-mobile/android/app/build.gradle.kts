plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "app.iz.mobile"
    // Firebase SDK 11 + AGP 8.x: compileSdk 35 gerekli (Android 15)
    compileSdk = 35
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Java 17: modern Kotlin ve tüm Firebase 11 bağımlılıkları için gerekli
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Desugaring: Java 8+ API'leri Android 6.0 (API 21) cihazlarda kullanabilmek için
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "app.iz.mobile"
        // Android 6.0+ (API 23): flutter_secure_storage ve SQLCipher için minimum
        // Bu, piyasadaki cihazların %99.5'ini kapsar (Android dashboard 2025)
        minSdk = 23
        // Android 15 (API 35): en son Android sürümünü hedefle
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // SQLCipher ABI filtreleri: boyutu küçültmek için
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64")
        }
    }

    buildTypes {
        release {
            // TODO: Yayın imzasını ekle. Şimdilik debug key kullanılıyor.
            signingConfig = signingConfigs.getByName("debug")
            // Release: kod küçültme ve kaynak daraltma
            isMinifyEnabled = false
            isShrinkResources = false
        }
        debug {
            isDebuggable = true
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring: API 23 altında Java 8+ stream/lambda desteği
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
