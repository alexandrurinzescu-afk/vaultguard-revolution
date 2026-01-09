# Android Studio Workspace Setup (VaultGuardRevolution)

This guide formalizes subpoint **1.1.3**: "Setup Android Studio workspace (confirmare manuala)".

## Goal
- Android Studio opens the project without sync errors
- Debug/Run configuration works on the target device (Motorola G05)
- No IDE-generated files are committed (keep repo clean)

## Prerequisites (expected in this repo)
- `gradlew.bat` present (Gradle wrapper)
- `local.properties` exists and contains `sdk.dir=...`
- Project root: `C:\Users\pc\VaultGuardRevolution`

## Step-by-step (Manual)
1. Open Android Studio
2. **Open** project folder: `C:\Users\pc\VaultGuardRevolution`
3. If prompted:
   - Use **Gradle JDK = 17**
   - Allow Gradle sync
4. Connect Motorola G05:
   - Enable Developer Options + USB debugging
   - Plug via USB (or use WiFi debugging)
5. In Android Studio:
   - Select run target device (Motorola G05)
   - Select `app` configuration
   - Run the app (Debug)

## Clean repo rules (IMPORTANT)
- Do **not** commit `.idea/` or other machine-specific IDE files
- This repo already ignores typical Android Studio generated folders

## Automated verification (recommended)
Run:

`powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\verify_android_studio_workspace.ps1"`

This script checks:
- JDK availability (`java -version`)
- `local.properties` and `sdk.dir`
- Gradle wrapper build (assembleDebug)
- Optional: `adb devices` if adb exists
- Optional: attempt to locate Android Studio executable and open the project

