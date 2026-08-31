plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.jobsflood.jobportal_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
