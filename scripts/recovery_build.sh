#!/usr/bin/env bash
set -euo pipefail

# Recovery build: attempts to fix common Gradle issues automatically.
# Non-interactive, safe to run repeatedly.

echo "Recovery build starting..."

./gradlew --stop || true

# Clean & refresh dependencies (network required).
./gradlew :app:clean --no-daemon || true
./gradlew :app:assembleDebug --refresh-dependencies --no-daemon
./gradlew :app:assembleRelease --refresh-dependencies --no-daemon

echo "Recovery build finished."

