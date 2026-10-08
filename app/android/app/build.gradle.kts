plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The Play upload key belongs to the account owner, NOT this repo.
// A release will fail unless every required signing variable is supplied.
val uploadStoreFile = System.getenv("SUKUN_UPLOAD_KEYSTORE_PATH")
val uploadStorePassword = System.getenv("SUKUN_UPLOAD_STORE_PASSWORD")
val uploadKeyAlias = System.getenv("SUKUN_UPLOAD_KEY_ALIAS")
val uploadKeyPassword = System.getenv("SUKUN_UPLOAD_KEY_PASSWORD")
val uploadSigningConfigured = listOf(
    uploadStoreFile,
    uploadStorePassword,
    uploadKeyAlias,
    uploadKeyPassword,
).all { !it.isNullOrBlank() }

val releaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true) || it.contains("bundle", ignoreCase = true)
}
if (releaseTaskRequested && !uploadSigningConfigured) {
    throw GradleException(
        "Android release requires approved Play upload-key signing variables; debug or unsigned releases are forbidden.",
    )
}

android {
    namespace = "com.sukunlife.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.sukunlife.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // flutter_secure_storage 11 uses Android Keystore ciphers that require
        // Android 6.0 (API 23) or newer.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (uploadSigningConfigured) {
            create("release") {
                storeFile = file(uploadStoreFile!!)
                storePassword = uploadStorePassword!!
                keyAlias = uploadKeyAlias!!
                keyPassword = uploadKeyPassword!!
            }
        }
    }

    buildTypes {
        release {
            if (uploadSigningConfigured) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
