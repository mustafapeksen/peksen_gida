import java.util.Base64
import java.io.File

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

// Signing credentials never enter Dart defines, source files or diagnostics.
// Debug builds remain usable when release credentials are absent or partial.
val releaseSigningNames = listOf(
    "PEKSEN_ANDROID_KEYSTORE", "PEKSEN_ANDROID_KEYSTORE_PASSWORD",
    "PEKSEN_ANDROID_KEY_ALIAS", "PEKSEN_ANDROID_KEY_PASSWORD",
)
val releaseSigning = releaseSigningNames.associateWith { System.getenv(it).orEmpty() }
val hasReleaseSigning = releaseSigning.values.all { it.isNotBlank() }
val validateReleaseSigning = tasks.register("validateReleaseSigning") {
    group = "verification"
    description = "Requires external release signing material; never falls back to debug."
    doLast {
        check(hasReleaseSigning) {
            "Release signing is not configured. See docs/RELEASE.md; no credential values are logged."
        }
        val keyFile = File(releaseSigning.getValue("PEKSEN_ANDROID_KEYSTORE"))
        check(keyFile.isAbsolute && keyFile.isFile &&
            !keyFile.canonicalFile.toPath().startsWith(rootDir.parentFile.canonicalFile.toPath())) {
            "Release keystore must be an existing absolute file outside the repository."
        }
        check(!releaseSigning.getValue("PEKSEN_ANDROID_KEY_ALIAS").equals("androiddebugkey", true) &&
            !keyFile.name.equals("debug.keystore", true)) {
            "Android debug signing material is not permitted for release."
        }
    }
}
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    dependsOn(validateReleaseSigning)
}

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

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseSigning.getValue("PEKSEN_ANDROID_KEYSTORE"))
                storePassword = releaseSigning.getValue("PEKSEN_ANDROID_KEYSTORE_PASSWORD")
                keyAlias = releaseSigning.getValue("PEKSEN_ANDROID_KEY_ALIAS")
                keyPassword = releaseSigning.getValue("PEKSEN_ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Missing credentials fail at preReleaseBuild, never unsigned/debug-signed output.
            if (hasReleaseSigning) signingConfig = signingConfigs.getByName("release")
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
