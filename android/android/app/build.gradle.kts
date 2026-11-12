import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.chaquo.python")
    id("dev.flutter.flutter-gradle-plugin")
}

val signingPath = System.getenv("TURBOSAVE_SIGNING_PROPERTIES")
val signingValues = Properties()
if (signingPath != null) file(signingPath).inputStream().use { signingValues.load(it) }

android {
    namespace = "com.turbosave.videodownloader"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    buildFeatures { buildConfig = true; resValues = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    defaultConfig {
        applicationId = "com.turbosave.mobile"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk { abiFilters += listOf("armeabi-v7a", "arm64-v8a") }
    }
    flavorDimensions += "policy"
    productFlavors {
        create("restricted") {
            dimension = "policy"
            applicationIdSuffix = ".restricted"
            resValue("string", "app_name", "TurboSave")
            buildConfigField("boolean", "RESTRICTED_SOURCES", "true")
        }
        create("unrestricted") {
            dimension = "policy"
            applicationIdSuffix = ".open"
            resValue("string", "app_name", "TurboSave Open")
            buildConfigField("boolean", "RESTRICTED_SOURCES", "false")
        }
    }
    signingConfigs {
        if (signingPath != null) create("localRelease") {
            storeFile = file(signingValues.getProperty("storeFile"))
            storePassword = signingValues.getProperty("storePassword")
            keyAlias = signingValues.getProperty("keyAlias")
            keyPassword = signingValues.getProperty("keyPassword")
        }
    }
    buildTypes {
        debug {
            applicationIdSuffix = ".test"
            versionNameSuffix = "-test"
        }
        release {
            if (signingPath != null) signingConfig = signingConfigs.getByName("localRelease")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    packaging { jniLibs { useLegacyPackaging = false } }
}

kotlin { compilerOptions { jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17 } }
chaquopy {
    defaultConfig {
        version = "3.11"
        val buildPythonPath = System.getenv("TURBOSAVE_BUILD_PYTHON")
        if (buildPythonPath != null) buildPython(buildPythonPath)
        pip { install("yt-dlp==2026.10.26"); install("certifi==2026.10.23") }
    }
}
flutter { source = "../.." }

dependencies { testImplementation("junit:junit:4.13.2") }
