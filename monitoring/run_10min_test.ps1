# VaultGuard Revolution - 10 minute monitoring system test harness
param([int]$Minutes = 10)

$ErrorActionPreference = "Stop"

$monitorRoot = "C:\VAULTGUARD_UNIVERSE\MONITORING"
$logsDir = Join-Path $monitorRoot "LOGS"
$statusLog = Join-Path $monitorRoot "test_status.log"
$resultJson = Join-Path $monitorRoot "test_result.json"
$hourlyDir = "C:\VAULTGUARD_UNIVERSE\HOURLY_REPORTS"

New-Item -ItemType Directory -Force -Path $monitorRoot | Out-Null
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
New-Item -ItemType Directory -Force -Path $hourlyDir | Out-Null

"STARTING $Minutes-MINUTE MONITORING SYSTEM TEST: $(Get-Date)" | Out-File -LiteralPath $statusLog -Encoding UTF8

$scripts = @(
  (Join-Path $monitorRoot "cursor_health_monitor.ps1"),
  (Join-Path $monitorRoot "hourly_intelligent_reporter.ps1")
)

$pids = @()
foreach ($s in $scripts) {
  if (Test-Path -LiteralPath $s) {
    $p = Start-Process powershell -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-File",$s) -WindowStyle Hidden -PassThru
    $pids += $p.Id
    ("STARTED {0} PID={1}" -f (Split-Path $s -Leaf), $p.Id) | Add-Content -LiteralPath $statusLog -Encoding UTF8
  } else {
    ("MISSING {0}" -f $s) | Add-Content -LiteralPath $statusLog -Encoding UTF8
  }
}

Start-Sleep -Seconds 5
$latestReport = Get-ChildItem -Path $hourlyDir -Filter "*.md" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($latestReport) {
  ("REPORT {0}" -f $latestReport.Name) | Add-Content -LiteralPath $statusLog -Encoding UTF8
}

$end = (Get-Date).AddMinutes($Minutes)
while ((Get-Date) -lt $end) {
  $remaining = $end - (Get-Date)

  $alive = @()
  foreach ($id in $pids) {
    if (Get-Process -Id $id -ErrorAction SilentlyContinue) { $alive += $id }
  }

  $newLogs = Get-ChildItem -Path $logsDir -Filter "*.log" -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-1) }

  $line = "TIMER {0}m {1}s | ALIVE {2}/{3} | LOGGING {4}" -f `
    ([math]::Floor($remaining.TotalMinutes)), $remaining.Seconds, $alive.Count, $pids.Count, ($(if ($newLogs) { "YES" } else { "NO" }))
  $line | Add-Content -LiteralPath $statusLog -Encoding UTF8

  Start-Sleep -Seconds 30
}

# stop processes we started
foreach ($id in $pids) {
  try { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue } catch { }
}

$finalLogs = Get-ChildItem -Path $logsDir -Filter "*.log" -ErrorAction SilentlyContinue
$finalReports = Get-ChildItem -Path $hourlyDir -Filter "*.md" -ErrorAction SilentlyContinue

$operational = (($finalLogs.Count -gt 0) -and ($finalReports.Count -gt 0))

$result = @{
  finishedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  pids = $pids
  logFiles = $finalLogs.Count
  reports = $finalReports.Count
  operational = $operational
}
Set-Content -LiteralPath $resultJson -Value ($result | ConvertTo-Json -Compress) -Encoding UTF8

("TEST COMPLETE | LOGS={0} REPORTS={1} STATUS={2}" -f $finalLogs.Count, $finalReports.Count, ($(if ($operational) { "OPERATIONAL" } else { "NEEDS_ATTENTION" }))) |
  Add-Content -LiteralPath $statusLog -Encoding UTF8

Write-Host ("TEST COMPLETE. Operational={0}. StatusLog={1}" -f $operational, $statusLog)

