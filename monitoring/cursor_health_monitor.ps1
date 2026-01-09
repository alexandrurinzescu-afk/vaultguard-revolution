param([switch]$Once)

. "$PSScriptRoot\monitoring_common.ps1"

$root = Get-MonitoringRoot
Ensure-Directory $root
Ensure-Directory (Join-Path $root "LOGS")

$logPath = Join-Path $root "LOGS\cursor_health_monitor.log"
Write-LogLine -LogPath $logPath -Level "INFO" -Message "Cursor health monitor started."

while ($true) {
  if (Test-StopFlag) {
    Write-LogLine -LogPath $logPath -Level "WARN" -Message "STOP_ALL.flag detected. Exiting."
    break
  }

  $load = Get-SystemLoad

  # 1) Cursor process check
  if (-not (Test-CursorRunning)) {
    Write-LogLine -LogPath $logPath -Level "ERROR" -Message "Cursor process not running. Restarting best-effort."
    Restart-CursorBestEffort -LogPath $logPath | Out-Null
    Start-Sleep -Seconds 30
    continue
  }

  # 2) Simple responsiveness test (filesystem)
  $responseSec = $null
  try {
    $response = Measure-Command {
      $testFile = Join-Path $root "response_test.tmp"
      "test" | Out-File -LiteralPath $testFile -Encoding ascii -Force
      Remove-Item -LiteralPath $testFile -Force -ErrorAction SilentlyContinue
    }
    $responseSec = [math]::Round($response.TotalSeconds, 2)
  } catch {
    $responseSec = 999
  }

  if ($responseSec -gt 10) {
    Write-LogLine -LogPath $logPath -Level "WARN" -Message ("Slow response detected: {0}s. Launching CursorStatus/Check best-effort." -f $responseSec)
    Invoke-DesktopToolBestEffort -Tool "CursorStatus" -LogPath $logPath | Out-Null
    Invoke-DesktopToolBestEffort -Tool "CursorCheck" -LogPath $logPath | Out-Null
  }

  # 3) Resource check (non-destructive)
  if (($load.CPU -ne $null -and $load.CPU -gt 90) -or ($load.Memory -ne $null -and $load.Memory -gt 90)) {
    Write-LogLine -LogPath $logPath -Level "WARN" -Message ("High resource usage detected. CPU={0} RAM={1}. Triggering lightweight checks." -f $load.CPU, $load.Memory)
    Invoke-DesktopToolBestEffort -Tool "CursorFixer" -LogPath $logPath | Out-Null
  }

  # 4) Motorola/adb connection check (best-effort)
  $adb = Test-AdbConnected
  if ($adb -eq $false) {
    Write-LogLine -LogPath $logPath -Level "WARN" -Message "ADB device not connected. Restarting adb best-effort."
    Restart-AdbBestEffort | Out-Null
  }

  # 5) Internet connectivity check
  $online = Test-Internet
  $offlineFlag = Join-Path $root "OFFLINE_MODE.flag"
  if (-not $online) {
    if (-not (Test-Path -LiteralPath $offlineFlag)) {
      Set-Content -LiteralPath $offlineFlag -Value "1" -Encoding ascii
    }
    Write-LogLine -LogPath $logPath -Level "WARN" -Message "Internet appears offline. OFFLINE_MODE.flag set."
  } else {
    if (Test-Path -LiteralPath $offlineFlag) { Remove-Item -LiteralPath $offlineFlag -Force -ErrorAction SilentlyContinue }
  }

  Start-Sleep -Seconds 30
  if ($Once) { break }
}

