import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing. The keystore and its passwords live in android/key.properties
// and android/keystore/, BOTH git-ignored, because a signing key in a public
// repository is the key itself given away.
//
// When the file is absent — a fresh clone, or CI without the secret — the build
// falls back to the debug key rather than failing. That keeps `flutter build`
// working for anyone, at the cost of an APK that Play will not accept, which is
// the right way round: an unsignable build that stops you is worse than a
// debug-signed one that is obviously not for release.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.jobsflood.jobportal_mobile"

    // Pinned to 36 rather than flutter.compileSdkVersion.
    //
    // flutter_plugin_android_lifecycle — pulled in by image_picker and
    // file_picker — publishes AAR metadata requiring API 36 or later, so the
    // Flutter default failed the build at :file_picker:checkReleaseAarMetadata
    // with "requires libraries and applications that depend on it to compile
    // against version 36 or later".
    //
    // compileSdk only decides which APIs are AVAILABLE at compile time; it does
    // not change the minimum Android version the app runs on. That is minSdk,
    // and it is untouched.
    compileSdk = 36

    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.jobsflood.jobportal_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                // PKCS12, not JKS: keytool on this machine has broken timezone
                // data and cannot generate a JKS at all, and PKCS12 is the
                // modern standard Android reads natively anyway.
                storeType = keystoreProperties.getProperty("storeType") ?: "PKCS12"
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
