Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Join-Path $PSScriptRoot ".."
Set-Location -Path $repoRoot

$reportsDir = Join-Path $repoRoot "reports"
New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null

$logPath = Join-Path $reportsDir "build_failures.log"

function Classify-Failure([string]$text) {
  $t = $text.ToLowerInvariant()
  if ($t -match "could not resolve" -or $t -match "read timed out" -or $t -match "connection timed out") { return "network/deps" }
  if ($t -match "manifest merger failed") { return "manifest" }
  if ($t -match "compiledebugkotlin failed" -or $t -match "compilation error") { return "kotlin" }
  if ($t -match "dex" -or $t -match "d8" -or $t -match "desugar") { return "dex/desugar" }
  if ($t -match "r8" -or $t -match "proguard") { return "r8/proguard" }
  return "unknown"
}

function Run-And-Capture([string]$task) {
  $ts = (Get-Date).ToString("s")
  $output = ""
  $success = $true
  try {
    $output = & .\gradlew.bat $task --no-daemon 2>&1 | Out-String
  } catch {
    $success = $false
    $output = $output + "`n" + ($_ | Out-String)
  }

  if (-not $success) {
    $cls = Classify-Failure $output
    "[$ts] task=$task class=$cls`n$output`n---" | Out-File -FilePath $logPath -Append -Encoding utf8
    throw "Build failed ($cls). Logged to $logPath"
  }
}

Run-And-Capture ":app:assembleDebug"

Write-Host "No failure detected."

