param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = "",

  [Parameter(Mandatory = $false)]
  [string]$QueueFile = "",

  [Parameter(Mandatory = $false)]
  [string]$StopFile = "",

  [Parameter(Mandatory = $false)]
  [int]$MaxRetries = 3
)

# Continuous runner (until STOP), with auto-recovery and backoff.
# - Reads commands from a queue text file (one command per line).
# - "STOP" line or stop file ends the loop.
# - On failure: runs cleanup_build_env.ps1, exponential backoff, retries.
# PowerShell 5.1 friendly.

$ErrorActionPreference = "Stop"

function Ensure-Dir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function NowTs() { return (Get-Date -Format "yyyyMMdd_HHmmss") }

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

$reportsDir = Join-Path $ProjectRoot "reports"
Ensure-Dir $reportsDir

if ([string]::IsNullOrWhiteSpace($QueueFile)) {
  $QueueFile = Join-Path $reportsDir "continuous_queue.txt"
}
if ([string]::IsNullOrWhiteSpace($StopFile)) {
  $StopFile = Join-Path $reportsDir "STOP_CONTINUOUS.txt"
}

$systemCheck = Join-Path $PSScriptRoot "system_check.ps1"
$cleanup = Join-Path $PSScriptRoot "cleanup_build_env.ps1"
$monitor = Join-Path $PSScriptRoot "stability_monitor.ps1"

Write-Host "RUN_CONTINUOUS - START" -ForegroundColor Cyan
Write-Host ("ProjectRoot: {0}" -f $ProjectRoot) -ForegroundColor Gray
Write-Host ("QueueFile:   {0}" -f $QueueFile) -ForegroundColor Gray
Write-Host ("StopFile:    {0}" -f $StopFile) -ForegroundColor Gray
Write-Host ""
Write-Host "To stop: create STOP file or add 'STOP' line in the queue file." -ForegroundColor Yellow

# Pre-flight
& $systemCheck -ProjectRoot $ProjectRoot | Out-Host
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Start monitor (best-effort, non-blocking)
try {
  Start-Process -FilePath "powershell" -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $monitor,
    "-ProjectRoot", $ProjectRoot,
    "-StopFile", $StopFile
  ) -WindowStyle Hidden | Out-Null
} catch { }

Ensure-Dir (Join-Path $reportsDir "incidents")
Ensure-Dir (Join-Path $reportsDir "continuous_logs")

if (-not (Test-Path -LiteralPath $QueueFile)) {
  New-Item -ItemType File -Force -Path $QueueFile | Out-Null
}

while ($true) {
  if (Test-Path -LiteralPath $StopFile) {
    Write-Host "STOP file detected. Exiting." -ForegroundColor Yellow
    break
  }

  $lines = @()
  try { $lines = @(Get-Content -LiteralPath $QueueFile -ErrorAction SilentlyContinue) } catch { }
  $lines = $lines | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

  if ($lines.Count -eq 0) {
    Start-Sleep -Seconds 5
    continue
  }

  # Pop first command, rewrite queue without it
  $cmd = $lines[0]
  $rest = @()
  if ($lines.Count -gt 1) { $rest = $lines[1..($lines.Count - 1)] }
  try { Set-Content -LiteralPath $QueueFile -Value ($rest -join "`r`n") -Encoding UTF8 } catch { }

  if ($cmd.ToUpperInvariant() -eq "STOP") {
    Write-Host "STOP command received. Exiting." -ForegroundColor Yellow
    break
  }

  $attempt = 0
  $ok = $false
  while (-not $ok -and $attempt -lt $MaxRetries) {
    $attempt++
    $ts = NowTs
    $log = Join-Path (Join-Path $reportsDir "continuous_logs") ("TASK_{0}_attempt{1}.log" -f $ts, $attempt)
    Write-Host ("Running (attempt {0}/{1}): {2}" -f $attempt, $MaxRetries, $cmd) -ForegroundColor White

    try {
      cmd.exe /d /c $cmd *> $log
      $exitCode = $LASTEXITCODE
      if ($exitCode -eq 0) {
        $ok = $true
        Write-Host "OK" -ForegroundColor Green
      } else {
        throw ("exit {0}" -f $exitCode)
      }
    } catch {
      $msg = $_.Exception.Message
      Write-Host ("FAIL: {0}" -f $msg) -ForegroundColor Red
      $inc = Join-Path (Join-Path $reportsDir "incidents") ("INCIDENT_{0}_attempt{1}.txt" -f $ts, $attempt)
      ("{0} | cmd={1} | error={2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $cmd, $msg) | Out-File -FilePath $inc -Encoding UTF8

      # Cleanup + backoff
      try { & $cleanup | Out-Host } catch { }
      $backoff = [math]::Min(60, [math]::Pow(2, $attempt) * 2)
      Start-Sleep -Seconds ([int]$backoff)
    }
  }

  if (-not $ok) {
    Write-Host "Max retries reached; continuing to next command." -ForegroundColor Yellow
  }
}

Write-Host "RUN_CONTINUOUS - END" -ForegroundColor Cyan

