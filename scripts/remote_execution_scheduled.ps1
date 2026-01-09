param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = "C:\Users\pc\AndroidStudioProjects\VaultGuard",

  # Stop time in CET/CEST (Windows tz: "Central European Standard Time")
  [Parameter(Mandatory = $false)]
  [int]$StopHourLocal = 9,

  [Parameter(Mandatory = $false)]
  [int]$StopMinuteLocal = 0,

  [Parameter(Mandatory = $false)]
  [string]$TimeZoneId = "Central European Standard Time",

  [Parameter(Mandatory = $false)]
  [switch]$NoWaitUntilStop,

  [Parameter(Mandatory = $false)]
  [switch]$SkipBuild,

  [Parameter(Mandatory = $false)]
  [switch]$SkipSecurityScan,

  [Parameter(Mandatory = $false)]
  [switch]$SkipBackup
)

# Scheduled remote execution runner (Phase-style).
# ASCII-only script for Windows PowerShell 5.1 parsing stability.

$ErrorActionPreference = "Stop"

function Ensure-Dir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function Now-Local([string]$tzId) {
  $tz = [TimeZoneInfo]::FindSystemTimeZoneById($tzId)
  return [TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, $tz)
}

function Compute-StopUtc([string]$tzId, [int]$h, [int]$m) {
  $tz = [TimeZoneInfo]::FindSystemTimeZoneById($tzId)
  $nowUtc = [DateTime]::UtcNow
  $nowLocal = [TimeZoneInfo]::ConvertTimeFromUtc($nowUtc, $tz)
  $stopLocal = $nowLocal.Date.AddHours($h).AddMinutes($m)
  if ($nowLocal -ge $stopLocal) { $stopLocal = $stopLocal.AddDays(1) }
  return [TimeZoneInfo]::ConvertTimeToUtc($stopLocal, $tz)
}

function Append-Line([string]$Path, [string]$Text) {
  $Text | Out-File -FilePath $Path -Append -Encoding UTF8
}

if (-not (Test-Path -LiteralPath $ProjectRoot)) {
  throw ("ProjectRoot not found: {0}" -f $ProjectRoot)
}

Set-Location -LiteralPath $ProjectRoot

$reportsDir = Join-Path $ProjectRoot "reports"
Ensure-Dir $reportsDir
Ensure-Dir (Join-Path $ProjectRoot "scripts")

$executionStartUtc = [DateTime]::UtcNow
$stopUtc = Compute-StopUtc -tzId $TimeZoneId -h $StopHourLocal -m $StopMinuteLocal
$stopLocal = Now-Local $TimeZoneId
$timeRemaining = $stopUtc - $executionStartUtc

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$checkpointFile = Join-Path $reportsDir ("execution_checkpoint_{0}.txt" -f $ts)

@"
VAULTGUARD REMOTE EXECUTION CHECKPOINT
=====================================
StartUtc: $executionStartUtc
StopUtc: $stopUtc
StopLocal: $( [TimeZoneInfo]::ConvertTimeFromUtc($stopUtc, [TimeZoneInfo]::FindSystemTimeZoneById($TimeZoneId)) )
TimeRemaining: $($timeRemaining.ToString())
"@ | Out-File -FilePath $checkpointFile -Encoding UTF8

Write-Output "EXECUTION TIMER SET"
Write-Output ("Start (local): {0}" -f (Get-Date -Format "HH:mm:ss"))
Write-Output ("Stop (local {0}): {1:HH:mm}" -f $TimeZoneId, ([TimeZoneInfo]::ConvertTimeFromUtc($stopUtc, [TimeZoneInfo]::FindSystemTimeZoneById($TimeZoneId))))
Write-Output ("Stop (UTC): {0:HH:mm}" -f $stopUtc)
Write-Output ("Time remaining: {0}" -f $timeRemaining)
Write-Output ("Checkpoint: {0}" -f $checkpointFile)

# PHASE 1: Analysis
$analysisReport = Join-Path $reportsDir ("PROJECT_ANALYSIS_{0}.txt" -f $ts)
@"
VAULTGUARD - PROJECT ANALYSIS
============================
Time: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Stop (UTC): $stopUtc
Root: $ProjectRoot

1) FILES BY EXTENSION
"@ | Out-File -FilePath $analysisReport -Encoding UTF8

Get-ChildItem -Path $ProjectRoot -Recurse -File -ErrorAction SilentlyContinue |
  Group-Object Extension |
  Sort-Object Count -Descending |
  ForEach-Object { Append-Line $analysisReport ("- {0}: {1}" -f $_.Name, $_.Count) }

Append-Line $analysisReport ""
Append-Line $analysisReport "2) SOURCE COUNTS"
$srcRoot = Join-Path $ProjectRoot "app\src"
$javaCount = (Get-ChildItem -Path $srcRoot -Recurse -Filter *.java -ErrorAction SilentlyContinue | Measure-Object).Count
$ktCount = (Get-ChildItem -Path $srcRoot -Recurse -Filter *.kt -ErrorAction SilentlyContinue | Measure-Object).Count
$xmlCount = (Get-ChildItem -Path $srcRoot -Recurse -Filter *.xml -ErrorAction SilentlyContinue | Measure-Object).Count
Append-Line $analysisReport ("- Java: {0}" -f $javaCount)
Append-Line $analysisReport ("- Kotlin: {0}" -f $ktCount)
Append-Line $analysisReport ("- XML: {0}" -f $xmlCount)

Append-Line $analysisReport ""
Append-Line $analysisReport "3) GIT STATUS"
if (Test-Path -LiteralPath (Join-Path $ProjectRoot ".git")) {
  $branch = (git rev-parse --abbrev-ref HEAD 2>$null)
  $commits = (git log --oneline 2>$null | Measure-Object).Count
  $changes = (git status --porcelain=v1 2>$null | Measure-Object).Count
  Append-Line $analysisReport ("- Repo: YES")
  Append-Line $analysisReport ("- Branch: {0}" -f $branch)
  Append-Line $analysisReport ("- Commits: {0}" -f $commits)
  Append-Line $analysisReport ("- Uncommitted: {0}" -f $changes)
} else {
  Append-Line $analysisReport "- Repo: NO"
}

Append-Line $analysisReport ""
Append-Line $analysisReport "4) BUILD STATUS"
if (Test-Path -LiteralPath (Join-Path $ProjectRoot "gradlew.bat")) { Append-Line $analysisReport "- gradlew.bat: YES" } else { Append-Line $analysisReport "- gradlew.bat: NO" }
$apkDir = Join-Path $ProjectRoot "app\build\outputs\apk\debug"
if (Test-Path -LiteralPath $apkDir) {
  $apk = Get-ChildItem -Path $apkDir -Filter *.apk -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($apk) { Append-Line $analysisReport ("- Latest APK: {0} ({1})" -f $apk.Name, $apk.LastWriteTime.ToString("yyyy-MM-dd HH:mm")) }
}

Write-Output ("Analysis saved: {0}" -f $analysisReport)

# Create auto backup script if missing
$autoBackupPath = Join-Path $ProjectRoot "scripts\auto_backup.ps1"
if (-not (Test-Path -LiteralPath $autoBackupPath)) {
  throw "scripts/auto_backup.ps1 missing (expected in repo)."
}

# PHASE 2: Build + tests
$buildLog = Join-Path $reportsDir ("BUILD_LOG_{0}.txt" -f $ts)
$buildSuccess = $false
if (-not $SkipBuild) {
  Append-Line $buildLog ("Build started: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
  if (Test-Path -LiteralPath (Join-Path $ProjectRoot "gradlew.bat")) {
    & .\gradlew.bat :app:assembleDebug --no-daemon 2>&1 | Tee-Object -FilePath $buildLog -Append | Out-Null
    if ($LASTEXITCODE -eq 0) { $buildSuccess = $true }
    if ($buildSuccess) {
      & .\gradlew.bat :app:testDebugUnitTest --no-daemon 2>&1 | Tee-Object -FilePath $buildLog -Append | Out-Null
    }
  }
  Append-Line $buildLog ("Build success: {0}" -f $buildSuccess)
  Write-Output ("Build log: {0}" -f $buildLog)
}

# PHASE 3: Security scan
$securityReport = Join-Path $reportsDir ("SECURITY_ANALYSIS_{0}.txt" -f $ts)
if (-not $SkipSecurityScan) {
  @"
VAULTGUARD SECURITY ANALYSIS
===========================
Time: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

1) Manifest permissions
"@ | Out-File -FilePath $securityReport -Encoding UTF8

  $manifestPath = Join-Path $ProjectRoot "app\src\main\AndroidManifest.xml"
  if (Test-Path -LiteralPath $manifestPath) {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw
    $perms = [regex]::Matches($manifest, "android\.permission\.\w+")
    if ($perms.Count -gt 0) {
  ($perms | ForEach-Object { $_.Value } | Select-Object -Unique) | ForEach-Object { Append-Line $securityReport ("- {0}" -f $_) }
    }
  }

  Append-Line $securityReport ""
  Append-Line $securityReport "2) Simple code scan (patterns)"
  $patterns = @(
    @{ Name = 'HTTP URLs'; Pattern = 'http://'; },
    @{ Name = 'Hardcoded secrets'; Pattern = '(?i)(password\s*=\s*["''][^"'']+["''])|(api[_-]?key\s*=)'; },
    @{ Name = 'Weak crypto'; Pattern = '(?i)MD5|SHA1|DES|RC4'; }
  )

  foreach ($p in $patterns) {
    $matches = Select-String -Path (Join-Path $ProjectRoot "app\src") -Recurse -Pattern $p.Pattern -ErrorAction SilentlyContinue
    Append-Line $securityReport ("- {0}: {1} hits" -f $p.Name, ($(if ($matches) { $matches.Count } else { 0 })))
  }

  Write-Output ("Security report: {0}" -f $securityReport)
}

# PHASE 4: Minimal docs + structure snapshot
$docsDir = Join-Path $ProjectRoot "docs"
Ensure-Dir $docsDir
$structureFile = Join-Path $docsDir ("PROJECT_STRUCTURE_{0}.md" -f $ts)

@"
## VaultGuard Project Structure (snapshot)
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

### Root
\`\`\`
$(Get-ChildItem -Path $ProjectRoot -Directory | Select-Object -ExpandProperty Name | Sort-Object | ForEach-Object { "- $_" } | Out-String)
\`\`\`
"@ | Out-File -FilePath $structureFile -Encoding UTF8

Write-Output ("Structure doc: {0}" -f $structureFile)

function Finalize-And-Exit {
  param([string]$Reason)

  $finalReport = Join-Path $reportsDir ("FINAL_EXECUTION_REPORT_{0}.txt" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
  $elapsed = [DateTime]::UtcNow - $executionStartUtc

  @"
FINAL EXECUTION REPORT - VAULTGUARD
==================================
Reason: $Reason
StartUtc: $executionStartUtc
StopUtc: $stopUtc
Elapsed: $elapsed

Artifacts:
- Checkpoint: $checkpointFile
- Analysis: $analysisReport
- Build log: $buildLog
- Security: $securityReport
- Structure: $structureFile

BuildSuccess: $buildSuccess
"@ | Out-File -FilePath $finalReport -Encoding UTF8

  Write-Output ("Final report: {0}" -f $finalReport)

  if (-not $SkipBackup) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $autoBackupPath -Label "SCHEDULED_STOP" | Out-Null
  }

  exit 0
}

if ($NoWaitUntilStop) {
  Finalize-And-Exit -Reason "Completed phases; NoWaitUntilStop set"
}

Write-Output "Waiting until scheduled stop time..."
while ($true) {
  $nowUtc = [DateTime]::UtcNow
  if ($nowUtc -ge $stopUtc) {
    Finalize-And-Exit -Reason "Reached scheduled stop time"
  }
  Start-Sleep -Seconds 60
}

