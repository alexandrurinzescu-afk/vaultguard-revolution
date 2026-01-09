. "$PSScriptRoot\monitoring_common.ps1"
. "$PSScriptRoot\recovery_orchestrator.ps1"

function Get-CursorLogTail {
  $paths = @(
    (Join-Path $env:LOCALAPPDATA "Cursor\logs"),
    (Join-Path $env:APPDATA "Cursor\logs")
  )
  foreach ($p in $paths) {
    if (Test-Path -LiteralPath $p) {
      $files = Get-ChildItem -LiteralPath $p -File -Filter "*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
      if ($files.Count -gt 0) {
        try { return (Get-Content -LiteralPath $files[0].FullName -Tail 200 -ErrorAction SilentlyContinue) -join "`n" } catch { }
      }
    }
  }
  return ""
}

function Monitor-SubpointExecution {
  param(
    [Parameter(Mandatory=$true)][string]$Subpoint,
    [int]$TimeoutMinutes = 30
  )

  $root = Get-MonitoringRoot
  Ensure-Directory $root
  Ensure-Directory (Join-Path $root "LOGS")
  Ensure-Directory (Join-Path $root "HOURLY_REPORTS")

  $logPath = Join-Path $root "LOGS\subpoint_execution_monitor.log"
  Write-LogLine -LogPath $logPath -Level "INFO" -Message ("Subpoint monitor started. Subpoint={0} Timeout={1}m" -f $Subpoint, $TimeoutMinutes)

  $start = Get-Date
  $deadline = $start.AddMinutes($TimeoutMinutes)
  $checkpoints = @()

  $blockingPatterns = @(
    "Error:",
    "Exception",
    "Timeout",
    "Not responding",
    "Failed to",
    "Could not",
    "Unable to",
    "Build failed",
    "Gradle",
    "Compilation error",
    "SDK not found"
  )

  while ((Get-Date) -lt $deadline) {
    if (Test-StopFlag) {
      Write-LogLine -LogPath $logPath -Level "WARN" -Message "STOP_ALL.flag detected. Exiting subpoint monitor."
      return @{ Success = $false; Reason = "Stopped" }
    }

    $tail = Get-CursorLogTail
    foreach ($p in $blockingPatterns) {
      if ($tail -match [regex]::Escape($p)) {
        Write-LogLine -LogPath $logPath -Level "ERROR" -Message ("Block pattern detected: {0}" -f $p)
        Invoke-UltimateRecovery -BlockType "Execution" -Subpoint $Subpoint | Out-Null
        break
      }
    }

    $elapsed = (Get-Date) - $start
    if (($elapsed.TotalMinutes -ge 1) -and (([int]$elapsed.TotalMinutes) % 5 -eq 0)) {
      $checkpoints += @{ Time = Get-Date; Minutes = [int]$elapsed.TotalMinutes; Subpoint = $Subpoint }
      $rp = Join-Path $root ("HOURLY_REPORTS\intermediate_{0}.md" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
      $lines = @()
      $lines += "# INTERMEDIATE PROGRESS REPORT"
      $lines += ("Generated: {0}" -f (Get-Date))
      $lines += ("Current Subpoint: {0}" -f $Subpoint)
      $lines += ("Elapsed: {0}" -f $elapsed)
      $lines += ""
      $lines += "Timeline:"
      foreach ($cp in $checkpoints) {
        $lines += ("- {0} - {1} minutes" -f $cp.Time.ToString("HH:mm:ss"), $cp.Minutes)
      }
      Set-Content -LiteralPath $rp -Value ($lines -join "`r`n") -Encoding UTF8
      Write-LogLine -LogPath $logPath -Level "INFO" -Message ("Intermediate report written: {0}" -f $rp)
    }

    Start-Sleep -Seconds 60
  }

  Write-LogLine -LogPath $logPath -Level "ERROR" -Message ("Timeout reached for subpoint: {0}" -f $Subpoint)
  Invoke-UltimateRecovery -BlockType "Timeout" -Subpoint $Subpoint | Out-Null
  return @{ Success = $false; Reason = "Timeout" }
}

