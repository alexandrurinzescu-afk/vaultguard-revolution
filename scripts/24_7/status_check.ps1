param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = ""
)

# Quick status check for the 24/7 system (PowerShell 5.1 friendly).

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
}

$dir = Join-Path $ProjectRoot "reports\\24_7_tracking"
$progress = Join-Path $dir "progress.csv"
$admin = Join-Path $dir "admin_blockers.md"
$queue = Join-Path $dir "task_queue.txt"
$control = Join-Path $dir "control_signal.txt"
$logsDir = Join-Path $dir "continuous_logs"

Write-Host "24/7 STATUS CHECK" -ForegroundColor Cyan
Write-Host ("Time:         {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss")) -ForegroundColor Gray
Write-Host ("Tracking dir: {0}" -f $dir) -ForegroundColor Gray
Write-Host ("Control:      {0}" -f $control) -ForegroundColor Gray

if (Test-Path -LiteralPath $control) {
  $sig = (Get-Content -LiteralPath $control -Raw -ErrorAction SilentlyContinue).Trim()
  if ($sig) { Write-Host ("Signal:       {0}" -f $sig) -ForegroundColor Yellow }
}

if (Test-Path -LiteralPath $queue) {
  $q = @(
    Get-Content -LiteralPath $queue -ErrorAction SilentlyContinue |
      Where-Object { $_.Trim() -ne "" -and (-not $_.Trim().StartsWith("#")) }
  )
  Write-Host ("Queued lines: {0}" -f $q.Count) -ForegroundColor Green
} else {
  Write-Host "Queue file missing." -ForegroundColor Yellow
}

if (Test-Path -LiteralPath $progress) {
  $count = (Get-Content -LiteralPath $progress | Measure-Object).Count
  Write-Host ("Progress rows: {0}" -f ($count - 1)) -ForegroundColor Green
} else {
  Write-Host "Progress file missing." -ForegroundColor Yellow
}

if (Test-Path -LiteralPath $admin) {
  $lines = (Get-Content -LiteralPath $admin | Measure-Object).Count
  Write-Host ("Admin blockers file: present ({0} lines)" -f $lines) -ForegroundColor Green
}

if (Test-Path -LiteralPath $logsDir) {
  $latestLog = Get-ChildItem -LiteralPath $logsDir -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($latestLog) {
    Write-Host ("Latest log:   {0}" -f $latestLog.Name) -ForegroundColor Green
  }
}

Write-Host ""
if (Test-Path -LiteralPath $progress) {
  Write-Host "Last 10 progress lines:" -ForegroundColor White
  Get-Content -LiteralPath $progress -Tail 10 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ }
}

