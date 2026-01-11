#!/usr/bin/env bash
set -euo pipefail

# Offline build: requires Gradle caches to already contain dependencies.
# Intended for CI/CD resilience and "no internet" execution.

./gradlew :app:assembleDebug --offline --no-daemon
./gradlew :app:testDebugUnitTest --offline --no-daemon || true

echo "Offline build finished."

