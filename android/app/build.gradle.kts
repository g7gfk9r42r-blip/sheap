import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Firebase Auth (requires android/app/google-services.json)
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.sheap.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.sheap.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 21)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Store-ready: Release signing must NOT use debug keys.
        // Provide android/key.properties (NOT committed). See docs/RELEASE.md.
        create("release") {
            val propsFile = rootProject.file("key.properties") // android/key.properties
            if (!propsFile.exists()) {
                throw GradleException(
                    "Missing android/key.properties for release signing. " +
                        "Create it (NOT committed) or build a non-release variant."
                )
            }
            val props = Properties()
            propsFile.inputStream().use { props.load(it) }

            val storeFilePath = props.getProperty("storeFile") ?: throw GradleException("key.properties missing storeFile")
            val storePassword = props.getProperty("storePassword") ?: throw GradleException("key.properties missing storePassword")
            val keyAlias = props.getProperty("keyAlias") ?: throw GradleException("key.properties missing keyAlias")
            val keyPassword = props.getProperty("keyPassword") ?: throw GradleException("key.properties missing keyPassword")

            // Resolve relative paths from the Android root (android/), not android/app/.
            // This lets key.properties use e.g. "keystore/upload-keystore.jks".
            storeFile = rootProject.file(storeFilePath)
            this.storePassword = storePassword
            this.keyAlias = keyAlias
            this.keyPassword = keyPassword
        }
    }

   buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")

        // IMPORTANT: Fix for Gradle error "Removing unused resources requires shrink..."
        isMinifyEnabled = false
        isShrinkResources = false
    }
}
}

flutter {
    source = "../.."
}

// -----------------------------------------------------------------------------
// Firebase config sync
// -----------------------------------------------------------------------------
// We keep the source-of-truth file at repo root:
//   roman_app/google/google-services.json
// (optionally also: roman_app/firebase/Google/google-services.json)
//
// The Google Services Gradle plugin reads ONLY:
//   android/app/google-services.json
//
// This task makes the build deterministic and avoids "wrong file" issues.
val syncGoogleServicesJson by tasks.registering(Copy::class) {
    val primary = rootProject.file("../google/google-services.json")
    val fallback = rootProject.file("../firebase/Google/google-services.json")

    val sourceFile = when {
        primary.exists() -> primary
        fallback.exists() -> fallback
        else -> null
    }

    if (sourceFile == null) {
        throw GradleException(
            "Missing google-services.json. Put it at roman_app/google/google-services.json " +
                "(or roman_app/firebase/Google/google-services.json)."
        )
    }

    from(sourceFile)
    into(project.projectDir)
    rename { "google-services.json" }

    // Gradle 8 validation: declare the concrete output file this task produces.
    // (Without this, other tasks reading android/app/google-services.json may trigger
    // "implicit dependency" problems.)
    outputs.file(file("google-services.json"))
}

// Ensure the sync runs before any google-services processing
tasks.whenTaskAdded {
    if (name.startsWith("process") && name.endsWith("GoogleServices")) {
        dependsOn(syncGoogleServicesJson)
    }
}

// Gradle 8 validation: Flutter compile tasks read android/app/google-services.json.
// Make the dependency explicit so task ordering is deterministic.
tasks.matching { it.name.startsWith("compileFlutterBuild") }.configureEach {
    dependsOn(syncGoogleServicesJson)
}

// Also ensure we have the file before general Android preBuild tasks run.
tasks.matching { it.name == "preBuild" || it.name.endsWith("PreBuild") }.configureEach {
    dependsOn(syncGoogleServicesJson)
}
