param(
  [Parameter(Mandatory = $true)]
  [string]$Mode,

  [Parameter(Mandatory = $false)]
  [string]$Subpoint = "",

  [Parameter(Mandatory = $false)]
  [string]$Description = "",

  [Parameter(Mandatory = $true)]
  [string]$Command,

  [Parameter(Mandatory = $true)]
  [string]$ProjectRoot,

  [Parameter(Mandatory = $true)]
  [string]$ProgressCsv,

  [Parameter(Mandatory = $true)]
  [string]$AdminBlockersMd,

  [Parameter(Mandatory = $false)]
  [int]$MaxRetries = 3
)

# Single-task processor with smart bypass + retries.
# Intended to be called by scripts/24_7/run_24_7.ps1.

$ErrorActionPreference = "Stop"

function NowIso() { return (Get-Date -Format "yyyy-MM-dd HH:mm:ss") }
function NowTs() { return (Get-Date -Format "yyyyMMdd_HHmmss") }
function CsvEscape([string]$s) { return '"' + ($s -replace '"', '""') + '"' }

. (Join-Path $PSScriptRoot "admin_detector.ps1")

function Append-Progress([string]$Task, [string]$Status, [double]$DurationSeconds, [string]$Notes) {
  $row = @(
    CsvEscape (NowIso),
    CsvEscape $Task,
    CsvEscape $Status,
    ([math]::Round($DurationSeconds, 2)).ToString(),
    CsvEscape $Notes
  ) -join ","
  Add-Content -LiteralPath $ProgressCsv -Value $row
}

function Log-AdminBlocker([string]$Task, [string]$Cmd, [string]$Reason) {
  $entry = @(
    "",
    "## " + (NowIso),
    "- **Task**: " + $Task,
    "- **Command**: `" + $Cmd + "`",
    "- **Reason**: " + $Reason,
    "- **Suggested manual fix**: Run as Administrator, then re-queue."
  ) -join "`r`n"
  Add-Content -LiteralPath $AdminBlockersMd -Value $entry
}

$taskName = $(if ($Mode -eq "TASK" -and $Subpoint) { $Subpoint } else { "CMD" })

if ((Test-AdminRequirement -CommandText $Command) -and (-not (Test-IsAdmin))) {
  Log-AdminBlocker -Task $taskName -Cmd $Command -Reason "ADMIN_BLOCKED (not elevated)"
  Append-Progress -Task $taskName -Status "ADMIN_BLOCKED" -DurationSeconds 0 -Notes "Skipped: admin privileges required."
  exit 10
}

$cleanup = Join-Path $ProjectRoot "scripts\\cleanup_build_env.ps1"
$backup = Join-Path $ProjectRoot "scripts\\backup_after_subpoint.ps1"

$attempt = 0
$ok = $false
$lastErr = ""
$start = Get-Date

while (-not $ok -and $attempt -lt $MaxRetries) {
  $attempt++
  $ts = NowTs
  $logDir = Join-Path $ProjectRoot "reports\\24_7_tracking\\logs"
  if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
  $logPath = Join-Path $logDir ("{0}_{1}_attempt{2}.log" -f $taskName.Replace(".","_"), $ts, $attempt)

  try {
    if ($attempt -gt 1 -and (Test-Path -LiteralPath $cleanup)) {
      try { & $cleanup | Out-Null } catch { }
    }
    cmd.exe /d /c $Command *> $logPath
    $exitCode = $LASTEXITCODE
    if ($exitCode -eq 0) { $ok = $true; break }
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
  exit 1
}

Append-Progress -Task $taskName -Status "SUCCESS" -DurationSeconds $dur -Notes "Command OK."

if ($Mode -eq "TASK" -and $Subpoint) {
  try {
    $chapter = ($Subpoint -replace "\\.\\d+$","")
    & $backup -Chapter $chapter -Subpoint $Subpoint -Description $Description | Out-Null
    Append-Progress -Task $taskName -Status "BACKUP_OK" -DurationSeconds 0 -Notes "backup_after_subpoint completed."
  } catch {
    Append-Progress -Task $taskName -Status "BACKUP_FAILED" -DurationSeconds 0 -Notes $_.Exception.Message
    exit 2
  }
}

exit 0

