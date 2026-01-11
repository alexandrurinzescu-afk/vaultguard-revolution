param(
  [Parameter(Mandatory = $false)]
  [switch]$KillJavaProcesses = $true,

  [Parameter(Mandatory = $false)]
  [switch]$CleanLocalCaches = $true
)

# Cleanup script for low-memory stability.
# - Kills orphaned Gradle/Java/Kotlin processes (best-effort).
# - Cleans repo-local caches only (.gradle/.kotlin) to avoid corrupt/inflated state.
# PowerShell 5.1 friendly.

$ErrorActionPreference = "Stop"

function Write-Info([string]$Msg) { Write-Host $Msg -ForegroundColor Cyan }
function Write-Ok([string]$Msg) { Write-Host $Msg -ForegroundColor Green }
function Write-Warn([string]$Msg) { Write-Host $Msg -ForegroundColor Yellow }

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location -LiteralPath $projectRoot

Write-Info "CLEANUP_BUILD_ENV"
Write-Info ("Project: {0}" -f $projectRoot)

if ($KillJavaProcesses) {
  $names = @("java", "javaw", "kotlin", "kotlinc", "gradle")
  foreach ($n in $names) {
    try {
      $procs = @(Get-Process -Name $n -ErrorAction SilentlyContinue)
      if ($procs.Count -gt 0) {
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Warn ("Stopped processes: {0} (count={1})" -f $n, $procs.Count)
      }
    } catch { }
  }
}

if ($CleanLocalCaches) {
  $paths = @(
    (Join-Path $projectRoot ".gradle"),
    (Join-Path $projectRoot ".kotlin"),
    (Join-Path $projectRoot "app\\.gradle"),
    (Join-Path $projectRoot "app\\.kotlin")
  )
  foreach ($p in $paths) {
    if (Test-Path -LiteralPath $p) {
      try {
        Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop
        Write-Warn ("Removed cache: {0}" -f $p)
      } catch {
        Write-Warn ("Failed to remove cache {0}: {1}" -f $p, $_.Exception.Message)
      }
    }
  }
}

try {
  [System.GC]::Collect()
  [System.GC]::WaitForPendingFinalizers()
} catch { }

Write-Ok "DONE"

