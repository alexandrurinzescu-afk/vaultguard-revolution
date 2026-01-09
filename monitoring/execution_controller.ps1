param([switch]$Once)

. "$PSScriptRoot\monitoring_common.ps1"
. "$PSScriptRoot\subpoint_execution_monitor.ps1"

$root = Get-MonitoringRoot
Ensure-Directory $root
Ensure-Directory (Join-Path $root "LOGS")

$logPath = Join-Path $root "LOGS\execution_controller.log"
Write-LogLine -LogPath $logPath -Level "INFO" -Message "Execution controller started."

# Work schedule (local time). Outside these windows we only monitor (no prompting).
$workSchedule = @(
  @{ Start = "08:00"; End = "12:00"; Intensity = "High" },
  @{ Start = "14:00"; End = "18:00"; Intensity = "High" },
  @{ Start = "20:00"; End = "22:00"; Intensity = "Medium" },
  @{ Start = "22:00"; End = "08:00"; Intensity = "Low" }
)

function Get-CurrentSchedule {
  $now = Get-Date
  foreach ($s in $workSchedule) {
    $start = [TimeSpan]::Parse($s.Start)
    $end = [TimeSpan]::Parse($s.End)
    if ($start -lt $end) {
      if ($now.TimeOfDay -ge $start -and $now.TimeOfDay -lt $end) { return $s }
    } else {
      # overnight window (e.g. 22:00 -> 08:00)
      if ($now.TimeOfDay -ge $start -or $now.TimeOfDay -lt $end) { return $s }
    }
  }
  return $null
}

while ($true) {
  if (Test-StopFlag) {
    Write-LogLine -LogPath $logPath -Level "WARN" -Message "STOP_ALL.flag detected. Exiting."
    break
  }

  $sched = Get-CurrentSchedule
  if ($sched) {
    Write-LogLine -LogPath $logPath -Level "INFO" -Message ("Active period. Intensity={0}" -f $sched.Intensity)

    $next = Get-NextIncompleteSubpoints -Count 1
    if ($next.Count -gt 0) {
      $sub = $next[0]
      $timeout = switch ($sched.Intensity) {
        "High" { 30 }
        "Medium" { 45 }
        "Low" { 60 }
        default { 30 }
      }

      # Monitoring-only: we do NOT auto-run coding steps; we only watch and recover toolchain blocks.
      $result = Monitor-SubpointExecution -Subpoint $sub -TimeoutMinutes $timeout
      Write-LogLine -LogPath $logPath -Level "INFO" -Message ("Monitor cycle done. Subpoint={0} Success={1} Reason={2}" -f $sub, $result.Success, $result.Reason)
    } else {
      Write-LogLine -LogPath $logPath -Level "INFO" -Message "No pending subpoints detected."
    }
  } else {
    Write-LogLine -LogPath $logPath -Level "INFO" -Message "Outside schedule. Health monitoring only."
  }

  Start-Sleep -Seconds 300
  if ($Once) { break }
}

