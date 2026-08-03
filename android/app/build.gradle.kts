plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val optivusStoreFile = System.getenv("OPTIVUS_ANDROID_STORE_FILE")
val optivusStorePassword = System.getenv("OPTIVUS_ANDROID_STORE_PASSWORD")
val optivusKeyAlias = System.getenv("OPTIVUS_ANDROID_KEY_ALIAS")
val optivusKeyPassword = System.getenv("OPTIVUS_ANDROID_KEY_PASSWORD")
val optivusReleaseSigningConfigured = listOf(
    optivusStoreFile,
    optivusStorePassword,
    optivusKeyAlias,
    optivusKeyPassword,
).all { !it.isNullOrBlank() }
val optivusReleaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (optivusReleaseTaskRequested && !optivusReleaseSigningConfigured) {
    throw GradleException(
        "Release signing is not configured. Set the four OPTIVUS_ANDROID_* signing variables.",
    )
}

android {
    namespace = "com.nairitroy.optivus"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.nairitroy.optivus"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (optivusReleaseSigningConfigured) {
            create("optivusRelease") {
                storeFile = file(optivusStoreFile!!)
                storePassword = optivusStorePassword
                keyAlias = optivusKeyAlias
                keyPassword = optivusKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("optivusRelease")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
