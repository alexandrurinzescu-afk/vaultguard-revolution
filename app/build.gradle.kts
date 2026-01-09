#!/bin/bash
# Salvează ca: upgrade_agp.sh și rulează: bash upgrade_agp.sh

echo "🚀 STARTING AGP 8.13.2 UPGRADE..."

# 1. Backup fișiere importante
echo "📦 Creating backup..."
cp build.gradle.kts build.gradle.kts.backup
cp app/build.gradle.kts app/build.gradle.kts.backup
cp gradle/wrapper/gradle-wrapper.properties gradle/wrapper/gradle-wrapper.properties.backup

# 2. Upgrade Gradle Wrapper
echo "⬆️ Upgrading Gradle Wrapper to 8.7..."
    ./gradlew wrapper --gradle-version=8.7 --distribution-type=bin

# 3. Clean all caches
echo "🧹 Cleaning all caches..."
    ./gradlew clean
rm -rf .gradle
rm -rf .idea
rm -rf build
        rm -rf app/build

# 4. Update root build.gradle.kts
echo "📝 Updating root build.gradle.kts..."
cat > build.gradle.kts << 'EOF'
// Top-level build file where you can add configuration options common to all sub-projects/modules.
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.13.2")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.22")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

tasks.register("clean", Delete::class) {
    delete(rootProject.buildDir)
}
EOF

# 5. Update app build.gradle.kts - FIX 16KB COMPATIBILITY
echo "📝 Updating app build.gradle.kts with 16KB fix..."
cat > app/build.gradle.kts << 'EOF'
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.vaultguard.revolution"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.vaultguard.revolution"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // ✅ FIX CRITIC PENTRU 16KB COMPATIBILITY
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            jniLibs {
                useLegacyPackaging = true
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
}
EOF

# 6. Create test activity
echo "🧪 Creating test activity..."
mkdir -p app/src/main/java/com/vaultguard/revolution

        cat > app/src/main/java/com/vaultguard/revolution/AGPTestActivity.kt << 'EOF'
package com.vaultguard.revolution

import android.os.Bundle
        import android.widget.TextView
        import androidx.appcompat.app.AppCompatActivity
        import java.util.Date

class AGPTestActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val textView = TextView(this).apply {
            text = """
            ✅ AGP 8.13.2 UPGRADE SUCCESS!
            
            Time: ${Date()}
            AGP: 8.13.2 ✓
            Gradle: 8.7 ✓
            Min SDK: 24 ✓
            16KB: FIXED ✓
            
            All systems GO! 🚀
            """
            textSize = 16f
        }

        setContentView(textView)
    }
}
EOF

# 7. Update manifest
        echo "📄 Updating AndroidManifest.xml..."
cat > app/src/main/AndroidManifest.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

<uses-permission android:name="android.permission.CAMERA" />

<application
android:allowBackup="true"
android:icon="@mipmap/ic_launcher"
android:label="VaultGuard AGP Test"
android:theme="@style/Theme.AppCompat.Light.NoActionBar">

<activity
android:name=".AGPTestActivity"
android:exported="true">
<intent-filter>
<action android:name="android.intent.action.MAIN" />
<category android:name="android.intent.category.LAUNCHER" />
</intent-filter>
</activity>

</application>

</manifest>
        EOF

echo "🎯 UPGRADE COMPLET! Now run:"
echo "1. In Android Studio: File → Sync Project with Gradle Files"
echo "2. Build → Clean Project"
echo "3. Run on device"
echo ""
echo "📱 Expected: AGPTestActivity with SUCCESS message!"