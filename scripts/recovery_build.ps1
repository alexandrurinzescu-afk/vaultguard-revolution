Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "Recovery build starting..."

Set-Location -Path (Join-Path $PSScriptRoot "..")

try { .\gradlew.bat --stop } catch { }

try { .\gradlew.bat :app:clean --no-daemon } catch { }

# Refresh dependencies and rebuild.
.\gradlew.bat :app:assembleDebug --refresh-dependencies --no-daemon
.\gradlew.bat :app:assembleRelease --refresh-dependencies --no-daemon

Write-Host "Recovery build finished."

