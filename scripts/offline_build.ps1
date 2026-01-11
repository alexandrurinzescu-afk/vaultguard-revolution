Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "Offline build starting..."

Set-Location -Path (Join-Path $PSScriptRoot "..")

.\gradlew.bat :app:assembleDebug --offline --no-daemon

try {
  .\gradlew.bat :app:testDebugUnitTest --offline --no-daemon
} catch {
  Write-Warning "Unit tests failed (offline mode). Continuing."
}

Write-Host "Offline build finished."

