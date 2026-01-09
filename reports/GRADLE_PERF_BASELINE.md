# Gradle Performance Baseline (Subpoint 1.1.4)

**Date:** 2026-01-09  
**Project:** VaultGuardRevolution (`C:\Users\pc\VaultGuardRevolution`)

## Toolchain
- Gradle wrapper: **8.6**
- JVM used by Gradle: **17.0.17**

## Measurements (this machine)
Measured via `scripts/gradle_perf_check.ps1`.

- **Clean build** (`gradlew clean assembleDebug`): ~**295.8s**
- **Incremental build** (`gradlew assembleDebug`): ~**14.6s** (after clean)  
- **Incremental build** (`gradlew assembleDebug`): ~**19.3s** (later re-run)

These numbers are highly dependent on disk speed, background activity, antivirus scanning, and daemon/cache warm-up.

## Optimizations enabled (safe defaults)
File: `gradle.properties`
- `org.gradle.caching=true`
- `org.gradle.vfs.watch=true`
- `org.gradle.parallel=true`
- `org.gradle.daemon=true`

## Practical next steps (if we want faster builds)
- Add Windows Defender exclusions for:
  - `C:\Users\pc\VaultGuardRevolution`
  - `%USERPROFILE%\.gradle`
  - Android SDK folder
- Keep Gradle daemon warm (avoid repeated `clean` unless necessary)
- Consider increasing `org.gradle.jvmargs` (only if RAM allows)
- Move the repo to a fast SSD path if currently on slower storage

