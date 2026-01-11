# Wrapper for compatibility with the requested folder structure.
. (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path "scripts\\admin_blocker_detector.ps1")
param()

# Wrapper for admin detection logic (PowerShell 5.1 friendly)
. (Join-Path $PSScriptRoot "..\\admin_blocker_detector.ps1")

