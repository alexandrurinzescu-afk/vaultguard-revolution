param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = "",

  [Parameter(Mandatory = $false)]
  [string]$QueueFile = "",

  [Parameter(Mandatory = $false)]
  [string]$ControlSignalFile = "",

  [Parameter(Mandatory = $false)]
  [int]$MaxRetries = 3
)

# 24/7 workflow runner (Smart Bypass) - scripts/24_7/*
# - Reads tasks from reports/24_7_tracking/continuous_queue.txt
# - Stops only on STOP (control_signal or STOP queue line)
# - Supports PAUSE (control_signal contains PAUSE)
# - Executes via scripts/24_7/task_processor.ps1 (retries + admin bypass)

$ErrorActionPreference = "Stop"

function Ensure-Dir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Read-Signal([string]$path) {
  try {
    $t = [string](Get-Content -LiteralPath $path -Raw -ErrorAction SilentlyContinue)
    $u = $t.ToUpperInvariant()
    if ($u.Contains("STOP")) { return "STOP" }
    if ($u.Contains("PAUSE")) { return "PAUSE" }
  } catch { }
  return ""
}

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
}
Set-Location -LiteralPath $ProjectRoot

$trackDir = Join-Path $ProjectRoot "reports\\24_7_tracking"
Ensure-Dir $trackDir
Ensure-Dir (Join-Path $trackDir "logs")
Ensure-Dir (Join-Path $trackDir "checkpoint_backups")

if ([string]::IsNullOrWhiteSpace($QueueFile)) {
  $QueueFile = Join-Path $trackDir "continuous_queue.txt"
}
if ([string]::IsNullOrWhiteSpace($ControlSignalFile)) {
  $ControlSignalFile = Join-Path $trackDir "control_signal.txt"
}

$progressCsv = Join-Path $trackDir "progress.csv"
$adminBlockersMd = Join-Path $trackDir "admin_blockers.md"

if (-not (Test-Path -LiteralPath $progressCsv)) {
  "Timestamp,Task,Status,DurationSeconds,Notes" | Out-File -FilePath $progressCsv -Encoding UTF8
}
if (-not (Test-Path -LiteralPath $adminBlockersMd)) {
  @(
    "# Admin Blockers (24/7 smart bypass)",
    "",
    "This file lists tasks/commands that were skipped because they likely require Administrator privileges.",
    ""
  ) | Out-File -FilePath $adminBlockersMd -Encoding UTF8
}
if (-not (Test-Path -LiteralPath $QueueFile)) { New-Item -ItemType File -Force -Path $QueueFile | Out-Null }
if (-not (Test-Path -LiteralPath $ControlSignalFile)) { New-Item -ItemType File -Force -Path $ControlSignalFile | Out-Null }

$processor = Join-Path $PSScriptRoot "task_processor.ps1"

function Pop-NextLine {
  $all = @()
  try { $all = @(Get-Content -LiteralPath $QueueFile -ErrorAction SilentlyContinue) } catch { }
  $all = $all | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" -and -not $_.StartsWith("#") }
  if ($all.Count -eq 0) { return $null }
  $head = $all[0]
  $rest = @()
  if ($all.Count -gt 1) { $rest = $all[1..($all.Count - 1)] }
  try { Set-Content -LiteralPath $QueueFile -Value ($rest -join "`r`n") -Encoding UTF8 } catch { }
  return $head
}

Write-Host "RUN_24_7 (scripts/24_7) - START" -ForegroundColor Cyan
Write-Host ("ProjectRoot: {0}" -f $ProjectRoot) -ForegroundColor Gray
Write-Host ("QueueFile:   {0}" -f $QueueFile) -ForegroundColor Gray
Write-Host ("Control:     {0} (STOP/PAUSE)" -f $ControlSignalFile) -ForegroundColor Gray
Write-Host ""

while ($true) {
  $sig = Read-Signal $ControlSignalFile
  if ($sig -eq "STOP") { Write-Host "STOP signal detected. Exiting." -ForegroundColor Yellow; break }
  if ($sig -eq "PAUSE") { Start-Sleep -Seconds 5; continue }

  $line = Pop-NextLine
  if ($null -eq $line) { Start-Sleep -Seconds 5; continue }
  if ($line.ToUpperInvariant() -eq "STOP") { Write-Host "STOP command received. Exiting." -ForegroundColor Yellow; break }

  $parts = $line.Split("|")
  $mode = $parts[0].Trim().ToUpperInvariant()

  $subpoint = ""
  $desc = ""
  $cmd = ""

  if ($mode -eq "TASK" -and $parts.Length -ge 4) {
    $subpoint = $parts[1].Trim()
    $desc = $parts[2].Trim()
    $cmd = ($parts[3..($parts.Length - 1)] -join "|").Trim()
  } elseif ($mode -eq "CMD" -and $parts.Length -ge 2) {
    $cmd = ($parts[1..($parts.Length - 1)] -join "|").Trim()
  } else {
    $mode = "CMD"
    $cmd = $line
  }

  $args = @(
    "-Mode", $mode,
    "-Command", $cmd,
    "-ProjectRoot", $ProjectRoot,
    "-ProgressCsv", $progressCsv,
    "-AdminBlockersMd", $adminBlockersMd,
    "-MaxRetries", $MaxRetries
  )
  if ($mode -eq "TASK") {
    $args += @("-Subpoint", $subpoint, "-Description", $desc)
  }

  try {
    & $processor @args | Out-Host
    $code = $LASTEXITCODE
    if ($code -eq 10) { continue } # admin blocked (already logged)
  } catch {
    # Worst-case: keep looping; processor already logs failures when it can
  }
}

Write-Host "RUN_24_7 (scripts/24_7) - END" -ForegroundColor Cyan

