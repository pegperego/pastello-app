import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (ADR 0016): from android/key.properties on a maintainer's
// machine, or from environment variables in the release workflow. Without
// them the release build is signed with the debug key, so pull request
// builds and `flutter run --release` keep working.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

fun signingValue(name: String, env: String): String? =
    keyProperties.getProperty(name) ?: System.getenv(env)

val releaseKeystore = signingValue("storeFile", "PASTELLO_KEYSTORE")

android {
    namespace = "io.github.pegperego.pastello"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.pegperego.pastello"
        // Android 10 (decision D-04, ADR 0002).
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseKeystore != null) {
            create("release") {
                storeFile = file(releaseKeystore)
                storePassword = signingValue("storePassword", "PASTELLO_KEYSTORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "PASTELLO_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "PASTELLO_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(
                if (releaseKeystore != null) "release" else "debug",
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
