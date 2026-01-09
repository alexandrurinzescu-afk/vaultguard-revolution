. "$PSScriptRoot\monitoring_common.ps1"

function Get-RecoveryLogPath {
  $root = Get-MonitoringRoot
  Ensure-Directory $root
  Ensure-Directory (Join-Path $root "LOGS")
  return (Join-Path $root "LOGS\recovery_orchestrator.log")
}

function Test-RecoverySuccess {
  param([string]$BlockType)
  switch ($BlockType) {
    "CursorDead" { return (Test-CursorRunning) }
    "AdbDisconnected" { $adb = Test-AdbConnected; return ($adb -eq $true) }
    default { return $true }
  }
}

function Invoke-UltimateRecovery {
  param(
    [Parameter(Mandatory=$true)][string]$BlockType,
    [string]$Subpoint
  )

  $logPath = Get-RecoveryLogPath
  Write-LogLine -LogPath $logPath -Level "ERROR" -Message ("Recovery activated. BlockType={0} Subpoint={1}" -f $BlockType, $Subpoint)

  $root = Get-MonitoringRoot
  Ensure-Directory (Join-Path $root "BLOCKS")
  $shot = Join-Path $root ("BLOCKS\block_{0}.png" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
  Try-TakeScreenshot -Path $shot -LogPath $logPath | Out-Null

  $sequence = @(
    @{ Name = "CursorRestart"; Action = { Restart-CursorBestEffort -LogPath $logPath | Out-Null } },
    @{ Name = "CursorCheck"; Action = { Invoke-DesktopToolBestEffort -Tool "CursorCheck" -LogPath $logPath | Out-Null } },
    @{ Name = "CursorFixer"; Action = { Invoke-DesktopToolBestEffort -Tool "CursorFixer" -LogPath $logPath | Out-Null } },
    @{ Name = "AdbRestart"; Action = { Restart-AdbBestEffort | Out-Null } }
  )

  foreach ($step in $sequence) {
    if (Test-StopFlag) {
      Write-LogLine -LogPath $logPath -Level "WARN" -Message "STOP_ALL.flag detected during recovery. Exiting recovery."
      return $false
    }

    Write-LogLine -LogPath $logPath -Level "INFO" -Message ("Attempting recovery step: {0}" -f $step.Name)
    try {
      & $step.Action
    } catch {
      Write-LogLine -LogPath $logPath -Level "WARN" -Message ("Recovery step failed: {0} - {1}" -f $step.Name, $_.Exception.Message)
    }

    Start-Sleep -Seconds 10
    if (Test-RecoverySuccess -BlockType $BlockType) {
      Write-LogLine -LogPath $logPath -Level "INFO" -Message ("Recovery successful with: {0}" -f $step.Name)
      return $true
    }
  }

  Write-LogLine -LogPath $logPath -Level "ERROR" -Message "All recovery steps exhausted."
  return $false
}

