param(
  [switch]$Once,
  [int]$IntervalMinutes = 60
)

. "$PSScriptRoot\monitoring_common.ps1"

function New-IntelligentHourlyReport {
  $root = Get-MonitoringRoot
  Ensure-Directory $root
  Ensure-Directory (Join-Path $root "HOURLY_REPORTS")
  Ensure-Directory (Join-Path $root "LOGS")
  Ensure-Directory "C:\VAULTGUARD_UNIVERSE\HOURLY_REPORTS"

  $logPath = Join-Path $root "LOGS\hourly_reporter.log"
  $reportPath = Join-Path $root ("HOURLY_REPORTS\hourly_{0}.md" -f (Get-Date -Format "yyyyMMdd_HHmm"))
  $chartPath = Join-Path $root "HOURLY_REPORTS\chart_data.jsonl"
  $reportPath2 = Join-Path "C:\VAULTGUARD_UNIVERSE\HOURLY_REPORTS" ("hourly_{0}.md" -f (Get-Date -Format "yyyyMMdd_HHmm"))

  $stats = Get-ProgressStats
  if (-not $stats) {
    Write-LogLine -LogPath $logPath -Level "ERROR" -Message "Roadmap not found; cannot generate report."
    return $false
  }

  $health = Get-SystemLoad
  $online = Test-Internet
  $adb = Test-AdbConnected

  $remaining = $stats.Remaining
  $avgPerHour = 0.2
  $hoursRemaining = if ($avgPerHour -gt 0) { [math]::Round($remaining / $avgPerHour, 1) } else { 999 }
  $eta = (Get-Date).AddHours($hoursRemaining)

  $next = Get-NextIncompleteSubpoints -Count 3

  $lines = @()
  $lines += "# HOURLY REPORT - VAULTGUARD REVOLUTION"
  $lines += ("Generated: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
  $lines += ""
  $lines += "Progress:"
  $lines += ("- Total Subpoints: {0}" -f $stats.Total)
  $lines += ("- Completed: {0}" -f $stats.Completed)
  $lines += ("- Remaining: {0}" -f $stats.Remaining)
  $lines += ("- Progress: {0}%" -f $stats.Percent)
  $lines += ""
  $lines += "System:"
  $lines += ("- Cursor: {0}" -f ($(if (Test-CursorRunning) { "Running" } else { "Stopped" })))
  $lines += ("- Internet: {0}" -f ($(if ($online) { "Online" } else { "Offline" })))
  $lines += ("- ADB: {0}" -f ($(if ($adb -eq $true) { "Connected" } elseif ($adb -eq $false) { "Disconnected" } else { "NotAvailable" })))
  $lines += ("- CPU: {0}" -f ($health.CPU))
  $lines += ("- RAM: {0}" -f ($health.Memory))
  $lines += ""
  $lines += "ETA (rough):"
  $lines += ("- Avg velocity assumed: {0} subpoints/hour" -f $avgPerHour)
  $lines += ("- Hours remaining: {0}" -f $hoursRemaining)
  $lines += ("- ETA: {0}" -f ($eta.ToString("yyyy-MM-dd HH:mm")))
  $lines += ""
  $lines += "Next subpoints:"
  if ($next.Count -eq 0) { $lines += "- (none detected)" } else { foreach ($n in $next) { $lines += ("- {0}" -f $n) } }
  $lines += ""
  $lines += "Notes:"
  $lines += "- This report is conservative; improve ETA by logging completions per day in a dedicated stats file if desired."

  Set-Content -LiteralPath $reportPath -Value ($lines -join "`r`n") -Encoding UTF8
  Set-Content -LiteralPath $reportPath2 -Value ($lines -join "`r`n") -Encoding UTF8
  Write-LogLine -LogPath $logPath -Level "INFO" -Message ("Hourly report written: {0}" -f $reportPath)

  $chartObj = @{
    timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm")
    completed = $stats.Completed
    total = $stats.Total
    cpu = $health.CPU
    memory = $health.Memory
    online = $online
  }
  Add-Content -LiteralPath $chartPath -Value (($chartObj | ConvertTo-Json -Compress) + "`r`n") -Encoding UTF8
  return $true
}

if ($Once) {
  New-IntelligentHourlyReport | Out-Null
  exit 0
}

if ($IntervalMinutes -lt 1) { $IntervalMinutes = 60 }

while ($true) {
  if (Test-StopFlag) { break }
  New-IntelligentHourlyReport | Out-Null
  Start-Sleep -Seconds ([int]($IntervalMinutes * 60))
}

