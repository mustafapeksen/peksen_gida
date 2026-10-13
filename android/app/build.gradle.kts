import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Public Firebase identifiers only. Generate native defaults as well as Dart
// options so Android can receive a notification when the Dart process is cold.
val publicDefines = (project.findProperty("dart-defines") as? String).orEmpty()
    .split(",").filter { it.isNotBlank() }.mapNotNull {
        val decoded = String(Base64.getDecoder().decode(it), Charsets.UTF_8)
        val pair = decoded.split("=", limit = 2)
        if (pair.size == 2) pair[0] to pair[1] else null
    }.toMap()
val firebaseResources = mapOf("FIREBASE_APP_ID" to "google_app_id",
    "FIREBASE_API_KEY" to "google_api_key", "FIREBASE_MESSAGING_SENDER_ID" to "gcm_defaultSenderId",
    "FIREBASE_PROJECT_ID" to "project_id")

android {
    namespace = "com.example.peksen_gida"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        if (firebaseResources.keys.all { !publicDefines[it].isNullOrBlank() }) {
            firebaseResources.forEach { (key, resource) -> resValue("string", resource, publicDefines.getValue(key)) }
        }
        // Faz 2 geliştirme kimliği; yayın öncesi değiştirilecek (DECISIONS T-01).
        applicationId = "com.example.peksen_gida"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Faz 17'de gerçek imzalama yapılandırılır (DECISIONS T-05).
            // Release için debug anahtarını kullanma.
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
