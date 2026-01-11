Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Join-Path $PSScriptRoot ".."
Set-Location -Path $repoRoot

$reportsDir = Join-Path $repoRoot "reports"
New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null

$csv = Join-Path $reportsDir "build_metrics.csv"
if (-not (Test-Path $csv)) {
  "timestamp,task,success,duration_ms" | Out-File -FilePath $csv -Encoding utf8
}

function Invoke-TimedGradle($task) {
  $start = Get-Date
  $success = $true
  try {
    .\gradlew.bat $task --no-daemon | Out-Host
  } catch {
    $success = $false
  }
  $end = Get-Date
  $duration = [int64]($end - $start).TotalMilliseconds
  $ts = (Get-Date).ToString("s")
  "$ts,$task,$success,$duration" | Out-File -FilePath $csv -Append -Encoding utf8
  if (-not $success) { throw "Gradle task failed: $task" }
}

Invoke-TimedGradle ":app:assembleDebug"
Invoke-TimedGradle ":app:assembleRelease"

Write-Host "Build metrics updated: $csv"

