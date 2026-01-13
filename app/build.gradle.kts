plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    // Align with existing Kotlin package: com.example.vaultguard.*
    namespace = "com.example.vaultguard"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.vaultguard"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            // Maximum security hardening: enable shrinking/obfuscation for release builds.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // Required for Compose + modern toolchain.
    buildFeatures {
        compose = true
    }

    composeOptions {
        // Kotlin 1.9.24 compatible.
        kotlinCompilerExtensionVersion = "1.5.14"
    }

    // Ensure packaged native libs stay compatible with some device constraints.
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
        jniLibs {
            useLegacyPackaging = true
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    // Local SDK jars (EyeCool etc.)
    implementation(fileTree("libs") { include("*.jar") })

    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.0")

    // Compose
    implementation(platform("androidx.compose:compose-bom:2024.06.00"))
    implementation("androidx.activity:activity-compose:1.9.0")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    debugImplementation("androidx.compose.ui:ui-tooling")

    // CameraX
    implementation("androidx.camera:camera-core:1.3.3")
    implementation("androidx.camera:camera-camera2:1.3.3")
    implementation("androidx.camera:camera-lifecycle:1.3.3")
    implementation("androidx.camera:camera-view:1.3.3")

    // Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.8.1")

    // ML Kit (face detection)
    implementation("com.google.mlkit:face-detection:16.1.6")
    // ML Kit (document scanner v2.1.6)
    implementation("com.google.mlkit:text-recognition:16.0.0")
    implementation("com.google.mlkit:text-recognition-chinese:16.0.0")
    implementation("com.google.mlkit:text-recognition-devanagari:16.0.0")
    implementation("com.google.mlkit:text-recognition-japanese:16.0.0")
    implementation("com.google.mlkit:text-recognition-korean:16.0.0")
    implementation("com.google.mlkit:object-detection:17.0.0")
    implementation("com.google.mlkit:barcode-scanning:17.2.0")

    // Views
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    implementation("com.google.android.material:material:1.12.0")

    // Biometrics (BiometricPrompt)
    implementation("androidx.biometric:biometric:1.1.0")

    // Background tasks (retention cleanup scheduler)
    implementation("androidx.work:work-runtime-ktx:2.9.0")

    // Tests (basic scaffold)
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test:core-ktx:1.6.1")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.6.1")

    // Java time (java.time.*) support for API < 26
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

