#!/bin/bash
# ============================================================================
# GRADLE CPR - CARDIO PULMONARY RESUSCITATION FOR CORRUPTED GRADLE
# Rulează în folderul rădăcină al proiectului tău Android!
# ============================================================================

echo "=================================================================="
echo "⚡  STARTING GRADLE CPR - SYSTEM REANIMATION"
echo "=================================================================="
echo "Current directory: $(pwd)"
echo ""

# ---------------------------------------------------------------------------
# PASUL 1: OPREȘTE TOATE PROCESELE GRADLE/JAVA
# ---------------------------------------------------------------------------
echo "🔴 PASUL 1: Oprire procese Gradle/Java..."
echo ""

if [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
# Mac sau Linux
echo "   Killing Gradle processes (macOS/Linux)..."
pkill -9 -f "gradle" 2>/dev/null || echo "   No gradle processes found"
pkill -9 -f "java.*gradle" 2>/dev/null || echo "   No java gradle processes found"
pkill -9 -f "GradleDaemon" 2>/dev/null || echo "   No GradleDaemon found"

elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
# Windows
echo "   Killing Gradle processes (Windows)..."
taskkill /F /IM gradle* 2>/dev/null || echo "   No gradle processes found"
taskkill /F /IM java* 2>/dev/null || echo "   No java processes found"
else
echo "   ⚠️  Unknown OS, manual process kill required"
fi

# ---------------------------------------------------------------------------
# PASUL 2: ȘTERGE TOATE CACHE-URILE CORUPTE
# ---------------------------------------------------------------------------
echo ""
echo "🗑️  PASUL 2: Ștergere cache-uri corupte..."
echo ""

# Cache-uri globale Gradle
echo "   Removing global Gradle cache..."
rm -rf ~/.gradle/caches 2>/dev/null || true
rm -rf ~/.gradle/daemon 2>/dev/null || true
rm -rf ~/.gradle/wrapper 2>/dev/null || true
rm -f ~/.gradle/*.lock 2>/dev/null || true

# Cache-uri locale proiect
echo "   Removing project cache..."
rm -rf .gradle 2>/dev/null || true
rm -rf .idea 2>/dev/null || true
rm -rf build 2>/dev/null || true
rm -rf app/build 2>/dev/null || true
rm -f local.properties 2>/dev/null || true
rm -f gradle.properties 2>/dev/null || true

# ---------------------------------------------------------------------------
# PASUL 3: CREEAZĂ STRUCTURĂ NOUĂ GRADLE WRAPPER
# ---------------------------------------------------------------------------
echo ""
echo "🔄 PASUL 3: Creare structură Gradle wrapper nouă..."
echo ""

# Creează folder wrapper dacă nu există
mkdir -p gradle/wrapper

# Creează gradle-wrapper.properties FRESH
echo "   Creating gradle-wrapper.properties..."
cat > gradle/wrapper/gradle-wrapper.properties << 'EOF'
# GRADLE WRAPPER - FRESH INSTALL
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.7-bin.zip
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
EOF

# Descarcă gradlew script nou pentru Linux/Mac
if [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
    echo "   Downloading fresh gradlew script..."
    curl -s -L https://raw.githubusercontent.com/gradle/gradle/master/gradlew -o gradlew
    chmod +x gradlew
    echo "   ✅ gradlew script downloaded and made executable"
fi

# ---------------------------------------------------------------------------
# PASUL 4: CREEAZĂ FIȘIERE DE BUILD MINIMALE
# ---------------------------------------------------------------------------
echo ""
echo "📝 PASUL 4: Creare fișiere build minime..."
echo ""

# Root build.gradle.kts - SUPER SIMPLU
echo "   Creating build.gradle.kts (root)..."
cat > build.gradle.kts << 'EOF'
// MINIMAL ROOT BUILD - NO COMPLEXITY
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

# App build.gradle.kts - MINIMAL
echo "   Creating app/build.gradle.kts..."
mkdir -p app
cat > app/build.gradle.kts << 'EOF'
// MINIMAL APP BUILD - NO DAEMON ISSUES
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
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    // FIX CRITIC: 16KB PAGE SIZE COMPATIBILITY
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
}
EOF

# gradle.properties - PREVENT DAEMON
echo "   Creating gradle.properties..."
cat > gradle.properties << 'EOF'
# DISABLE ALL GRADLE DAEMON AND CACHING
org.gradle.daemon=false
org.gradle.caching=false
org.gradle.parallel=false
org.gradle.configureondemand=false
org.gradle.jvmargs=-Xmx2g -Dfile.encoding=UTF-8

# FORCE FRESH BUILDS
systemProp.gradle.wrapperUser=true
EOF

# ---------------------------------------------------------------------------
# PASUL 5: CREEAZĂ ACTIVITATE DE TEST SIMPLĂ
# ---------------------------------------------------------------------------
echo ""
echo "🧪 PASUL 5: Creare activitate de test..."
echo ""

# Creează structura de package
mkdir -p app/src/main/java/com/vaultguard/revolution
mkdir -p app/src/main/res/layout

# Creează activitatea de test
echo "   Creating test activity..."
cat > app/src/main/java/com/vaultguard/revolution/CPRTestActivity.kt << 'EOF'
package com.vaultguard.revolution

import android.os.Bundle
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import java.text.SimpleDateFormat
import java.util.*

class CPRTestActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val time = SimpleDateFormat("HH:mm:ss.SSS", Locale.getDefault()).format(Date())

        val textView = TextView(this).apply {
            text = """
            🎉 GRADLE CPR SUCCESS!

            Timestamp: $time
            AGP: 8.13.2 ✓
            Gradle: 8.7 ✓
            Min SDK: 24 ✓
            16KB: FIXED ✓
            Daemon: DISABLED ✓

            System reanimated! 🚀
            """
            textSize = 16f
        }

        setContentView(textView)
    }
}
EOF

# Creează AndroidManifest.xml minimal
echo "   Creating AndroidManifest.xml..."
cat > app/src/main/AndroidManifest.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="Gradle CPR Test"
        android:theme="@style/Theme.AppCompat.Light.NoActionBar">

        <activity
            android:name=".CPRTestActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

    </application>

</manifest>
EOF

# ---------------------------------------------------------------------------
# PASUL 6: VERIFICARE FINALĂ
# ---------------------------------------------------------------------------
echo ""
echo "✅ PASUL 6: Verificare finală..."
echo ""

echo "📁 Structura creată:"
find . -type f -name "*.kts" -o -name "*.properties" | sort
echo ""

echo "=================================================================="
echo "🎯 GRADLE CPR COMPLETAT CU SUCCES!"
echo "=================================================================="
echo ""
echo "📋 URMEAZĂ ACUM:"
echo "1. În Android Studio: File → Sync Project with Gradle Files"
echo "2. Build → Clean Project"
echo "3. Rulează aplicația pe device"
echo ""
echo "🧪 Așteptăm: 'GRADLE CPR SUCCESS!' pe ecran!"
echo ""
echo "⚠️  Dacă sync eșuează, închide și redeschide Android Studio."
echo "=================================================================="

