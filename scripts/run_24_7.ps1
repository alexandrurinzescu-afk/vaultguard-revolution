param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = "",

  # Queue format:
  # - TASK|<Subpoint>|<Description>|<Command>
  # - CMD|<Command>
  # - STOP
  [Parameter(Mandatory = $false)]
  [string]$QueueFile = "",

  [Parameter(Mandatory = $false)]
  [string]$ControlSignalFile = "",

  [Parameter(Mandatory = $false)]
  [int]$MaxRetries = 3
)

# 24/7 continuous workflow runner with smart bypass:
# - Runs until manual STOP (control file contains STOP or STOP line in queue).
# - Logs progress to reports/progress_tracker.csv
# - Logs admin blockers to reports/admin_blockers.md
# - On successful TASK items: runs backup_after_subpoint.ps1 (roadmap update + git commit + zip)
# PowerShell 5.1 friendly.

$ErrorActionPreference = "Stop"

function Ensure-Dir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function NowIso() { return (Get-Date -Format "yyyy-MM-dd HH:mm:ss") }
function NowTs() { return (Get-Date -Format "yyyyMMdd_HHmmss") }
function CsvEscape([string]$s) { return '"' + ($s -replace '"', '""') + '"' }

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}
Set-Location -LiteralPath $ProjectRoot

$reportsDir = Join-Path $ProjectRoot "reports"
$trackingDir = Join-Path $reportsDir "24_7_tracking"
$logsDir = Join-Path $trackingDir "continuous_logs"
Ensure-Dir $reportsDir
Ensure-Dir $trackingDir
Ensure-Dir $logsDir

if ([string]::IsNullOrWhiteSpace($QueueFile)) {
  $QueueFile = Join-Path $trackingDir "task_queue.txt"
}
if ([string]::IsNullOrWhiteSpace($ControlSignalFile)) {
  $ControlSignalFile = Join-Path $trackingDir "control_signal.txt"
}

$progressCsv = Join-Path $trackingDir "progress.csv"
$adminBlockersMd = Join-Path $trackingDir "admin_blockers.md"

if (-not (Test-Path -LiteralPath $progressCsv)) {
  "Timestamp,Task,Status,DurationSeconds,Notes" | Out-File -FilePath $progressCsv -Encoding UTF8
}
if (-not (Test-Path -LiteralPath $adminBlockersMd)) {
  @(
    "# Admin Blockers (auto-collected)",
    "",
    "This file lists tasks/commands that were skipped because they likely require Administrator privileges.",
    ""
  ) | Out-File -FilePath $adminBlockersMd -Encoding UTF8
}

if (-not (Test-Path -LiteralPath $QueueFile)) { New-Item -ItemType File -Force -Path $QueueFile | Out-Null }
if (-not (Test-Path -LiteralPath $ControlSignalFile)) { New-Item -ItemType File -Force -Path $ControlSignalFile | Out-Null }

# Load helpers
. (Join-Path $PSScriptRoot "admin_blocker_detector.ps1")

$cleanup = Join-Path $PSScriptRoot "cleanup_build_env.ps1"
$systemCheck = Join-Path $PSScriptRoot "system_check.ps1"
$backup = Join-Path $PSScriptRoot "backup_after_subpoint.ps1"

function Append-Progress([string]$Task, [string]$Status, [double]$DurationSeconds, [string]$Notes) {
  $row = @(
    CsvEscape (NowIso),
    CsvEscape $Task,
    CsvEscape $Status,
    ([math]::Round($DurationSeconds, 2)).ToString(),
    CsvEscape $Notes
  ) -join ","
  Add-Content -LiteralPath $progressCsv -Value $row
}

function Log-AdminBlocker([string]$Task, [string]$Command, [string]$Reason) {
  $tick = '`'
  $entry = @(
    "",
    "## " + (NowIso),
    "- **Task**: " + $Task,
    ("- **Command**: " + $tick + $Command + $tick),
    "- **Reason**: " + $Reason,
    "- **Suggested manual fix**: Run as Administrator, then re-queue as TASK/CMD."
  ) -join "`r`n"
  Add-Content -LiteralPath $adminBlockersMd -Value $entry
}

function Pop-NextQueueLine {
  $lines = @()
  try { $lines = @(Get-Content -LiteralPath $QueueFile -ErrorAction SilentlyContinue) } catch { }
  # IMPORTANT: force array output so a single remaining queue line doesn't collapse into a scalar string.
  $lines = @(
    $lines |
      ForEach-Object { [string]$_.Trim() } |
      Where-Object { $_ -ne "" -and (-not $_.StartsWith("#")) }
  )
  if ($lines.Count -eq 0) { return $null }
  $head = $lines[0]
  $rest = @()
  if ($lines.Count -gt 1) { $rest = $lines[1..($lines.Count - 1)] }
  try { Set-Content -LiteralPath $QueueFile -Value ($rest -join "`r`n") -Encoding UTF8 } catch { }
  return $head
}

function Read-ControlSignal {
  try {
    $t = (Get-Content -LiteralPath $ControlSignalFile -Raw -ErrorAction SilentlyContinue)
    if ($t -and $t.ToUpperInvariant().Contains("STOP")) { return "STOP" }
    if ($t -and $t.ToUpperInvariant().Contains("PAUSE")) { return "PAUSE" }
  } catch { }
  return ""
}

Write-Host "RUN_24_7 - START" -ForegroundColor Cyan
Write-Host ("ProjectRoot: {0}" -f $ProjectRoot) -ForegroundColor Gray
Write-Host ("QueueFile:   {0}" -f $QueueFile) -ForegroundColor Gray
Write-Host ("Control:     {0} (write STOP/PAUSE to control)" -f $ControlSignalFile) -ForegroundColor Gray
Write-Host ("Admin:       {0}" -f (Test-IsAdmin)) -ForegroundColor Gray
Write-Host ""

# Pre-flight (best-effort; paging may be unreadable)
try { & $systemCheck -ProjectRoot $ProjectRoot | Out-Host } catch { }

while ($true) {
  $sig = Read-ControlSignal
  if ($sig -eq "STOP") {
    Write-Host "STOP signal detected. Exiting." -ForegroundColor Yellow
    break
  }
  if ($sig -eq "PAUSE") {
    Start-Sleep -Seconds 5
    continue
  }

  $line = Pop-NextQueueLine
  if ($null -eq $line) {
    Start-Sleep -Seconds 5
    continue
  }

  $line = [string]$line
  if ($line.ToUpperInvariant() -eq "STOP") {
    Write-Host "STOP command received from queue. Exiting." -ForegroundColor Yellow
    break
  }

  $parts = $line.Split("|")
  $mode = $parts[0].Trim().ToUpperInvariant()

  $taskName = $line
  $subpoint = ""
  $desc = ""
  $command = ""

  if ($mode -eq "TASK" -and $parts.Length -ge 4) {
    $subpoint = $parts[1].Trim()
    $desc = $parts[2].Trim()
    $command = ($parts[3..($parts.Length - 1)] -join "|").Trim()
    $taskName = $subpoint
  } elseif ($mode -eq "CMD" -and $parts.Length -ge 2) {
    $command = ($parts[1..($parts.Length - 1)] -join "|").Trim()
    $taskName = "CMD"
  } else {
    # Unknown line format: treat as raw CMD
    $mode = "CMD"
    $command = $line
    $taskName = "CMD"
  }

  # Smart bypass: admin-requiring commands
  if ((Test-AdminRequirement -CommandText $command) -and (-not (Test-IsAdmin))) {
    Log-AdminBlocker -Task $taskName -Command $command -Reason "ADMIN_BLOCKED (not elevated)"
    Append-Progress -Task $taskName -Status "ADMIN_BLOCKED" -DurationSeconds 0 -Notes "Skipped: admin privileges required."
    continue
  }

  $attempt = 0
  $start = Get-Date
  $ok = $false
  $lastErr = ""

  while (-not $ok -and $attempt -lt $MaxRetries) {
    $attempt++
    $ts = NowTs
    $logPath = Join-Path $logsDir ("{0}_{1}_attempt{2}.log" -f $taskName.Replace(".","_"), $ts, $attempt)

    try {
      # Always run cleanup before retry attempts >1
      if ($attempt -gt 1) {
        try { & $cleanup | Out-Host } catch { }
      }

      cmd.exe /d /c $command *> $logPath
      $exitCode = $LASTEXITCODE
      if ($exitCode -eq 0) {
        $ok = $true
        break
      }
      throw ("exit {0}" -f $exitCode)
    } catch {
      $lastErr = $_.Exception.Message
      $backoff = [math]::Min(60, [math]::Pow(2, $attempt) * 2)
      Start-Sleep -Seconds ([int]$backoff)
    }
  }

  $dur = (New-TimeSpan -Start $start -End (Get-Date)).TotalSeconds

  if (-not $ok) {
    Append-Progress -Task $taskName -Status "FAILED" -DurationSeconds $dur -Notes ("Error: {0}" -f $lastErr)
    continue
  }

  # Success path
  Append-Progress -Task $taskName -Status "SUCCESS" -DurationSeconds $dur -Notes "Command OK."

  # If this was a TASK, run backup protocol (roadmap update + git tag + zip)
  if ($mode -eq "TASK" -and -not [string]::IsNullOrWhiteSpace($subpoint)) {
    try {
      $chapter = ($subpoint -replace "\\.\\d+$","")
      & $backup -Chapter $chapter -Subpoint $subpoint -Description $desc | Out-Host
      Append-Progress -Task $taskName -Status "BACKUP_OK" -DurationSeconds 0 -Notes "backup_after_subpoint completed."
    } catch {
      Append-Progress -Task $taskName -Status "BACKUP_FAILED" -DurationSeconds 0 -Notes $_.Exception.Message
    }
  }
}

try {
  $finalPath = Join-Path $trackingDir ("final_report_{0}.md" -f (NowTs))
  $lines = @()
  $lines += ("# FINAL REPORT ({0})" -f (NowIso))
  $lines += ""
  $lines += ("- Queue: {0}" -f $QueueFile)
  $lines += ("- Progress: {0}" -f $progressCsv)
  $lines += ("- Admin blockers: {0}" -f $adminBlockersMd)
  $lines += ""
  $lines += "## Summary"
  if (Test-Path -LiteralPath $progressCsv) {
    $rows = @(Get-Content -LiteralPath $progressCsv -ErrorAction SilentlyContinue | Select-Object -Skip 1)
    $lines += ("- Total rows: {0}" -f $rows.Count)
    $lines += ("- SUCCESS: {0}" -f ($rows | Select-String -SimpleMatch ",\"SUCCESS\"," | Measure-Object).Count)
    $lines += ("- ADMIN_BLOCKED: {0}" -f ($rows | Select-String -SimpleMatch ",\"ADMIN_BLOCKED\"," | Measure-Object).Count)
    $lines += ("- FAILED: {0}" -f ($rows | Select-String -SimpleMatch ",\"FAILED\"," | Measure-Object).Count)
  } else {
    $lines += "- No progress file found."
  }
  ($lines -join "`r`n") | Out-File -FilePath $finalPath -Encoding UTF8
} catch { }

Write-Host "RUN_24_7 - END" -ForegroundColor Cyan

