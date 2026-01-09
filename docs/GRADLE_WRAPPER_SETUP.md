# Gradle Wrapper Setup (Subpoint 1.1.4)

This document records the project Gradle wrapper + performance settings.

## Current wrapper (authoritative)
- Wrapper file: `gradle/wrapper/gradle-wrapper.properties`
- Distribution: **Gradle 8.6**

Why: `build.gradle.kts` uses Android Gradle Plugin **8.4.2**, which is compatible with Gradle 8.6 in this repo.

## Performance settings (safe defaults)
File: `gradle.properties`
- `org.gradle.caching=true` (build cache)
- `org.gradle.vfs.watch=true` (faster incremental file watching)
- `org.gradle.parallel=true` (parallel execution where possible)
- `org.gradle.jvmargs=... -XX:+UseParallelGC` (stable GC)

## Verification commands
From repo root:
- `.\gradlew.bat --version`
- `.\gradlew.bat tasks`
- `.\gradlew.bat clean assembleDebug`
- `.\gradlew.bat assembleDebug` (incremental)

Or run:
`powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\gradle_perf_check.ps1"`

