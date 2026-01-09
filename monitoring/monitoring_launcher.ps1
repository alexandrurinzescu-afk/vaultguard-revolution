param([switch]$Once)

. "$PSScriptRoot\monitoring_common.ps1"

$root = Get-MonitoringRoot
Ensure-Directory $root
Ensure-Directory (Join-Path $root "LOGS")
Ensure-Directory (Join-Path $root "HOURLY_REPORTS")

$logPath = Join-Path $root "LOGS\monitoring_launcher.log"
Write-LogLine -LogPath $logPath -Level "INFO" -Message "Monitoring launcher started."

$health = Join-Path $root "cursor_health_monitor.ps1"
$controller = Join-Path $root "execution_controller.ps1"
$hourly = Join-Path $root "hourly_intelligent_reporter.ps1"
$dailyAudit = Join-Path (Get-ProjectRoot) "scripts\daily_protocol_audit.ps1"

function Start-LoopProcess {
  param([string]$ScriptPath, [string]$Name)
  if (-not (Test-Path -LiteralPath $ScriptPath)) {
    Write-LogLine -LogPath $logPath -Level "WARN" -Message ("Missing script for {0}: {1}" -f $Name, $ScriptPath)
    return $false
  }
  Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-File",$ScriptPath) -WindowStyle Hidden | Out-Null
  Write-LogLine -LogPath $logPath -Level "INFO" -Message ("Started loop process: {0}" -f $Name)
  return $true
}

if (-not $Once) {
  Start-LoopProcess -ScriptPath $health -Name "CursorHealthMonitor" | Out-Null
  Start-LoopProcess -ScriptPath $controller -Name "ExecutionController" | Out-Null
}

# Scheduler loops (hourly + daily) without Task Scheduler.
$statePath = Join-Path $root "launcher_state.json"
$lastHourly = $null
$lastDaily = $null
if (Test-Path -LiteralPath $statePath) {
  try {
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    $lastHourly = $state.lastHourly
    $lastDaily = $state.lastDaily
  } catch { }
}

function Save-State {
  $obj = @{ lastHourly = $lastHourly; lastDaily = $lastDaily }
  Set-Content -LiteralPath $statePath -Value ($obj | ConvertTo-Json -Compress) -Encoding UTF8
}

function Run-Hourly {
  if (Test-Path -LiteralPath $hourly) {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $hourly -Once | Out-Null
    $script:lastHourly = (Get-Date -Format "yyyy-MM-dd HH:00")
    Write-LogLine -LogPath $logPath -Level "INFO" -Message ("Hourly report run: {0}" -f $script:lastHourly)
    Save-State
  }
}

function Run-DailyAudit {
  if (Test-Path -LiteralPath $dailyAudit) {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $dailyAudit | Out-Null
    $script:lastDaily = (Get-Date -Format "yyyy-MM-dd")
    Write-LogLine -LogPath $logPath -Level "INFO" -Message ("Daily protocol audit run: {0}" -f $script:lastDaily)
    Save-State
  }
}

if ($Once) {
  Run-Hourly
  # Run daily audit if today and after 09:00 and not run yet
  if ((Get-Date).Hour -ge 9 -and $lastDaily -ne (Get-Date -Format "yyyy-MM-dd")) {
    Run-DailyAudit
  }
  Write-LogLine -LogPath $logPath -Level "INFO" -Message "Launcher once-mode complete."
  exit 0
}

while ($true) {
  if (Test-StopFlag) {
    Write-LogLine -LogPath $logPath -Level "WARN" -Message "STOP_ALL.flag detected. Exiting launcher scheduler loop."
    break
  }

  $nowHour = Get-Date -Format "yyyy-MM-dd HH:00"
  if ($lastHourly -ne $nowHour) {
    Run-Hourly
  }

  $today = Get-Date -Format "yyyy-MM-dd"
  if ((Get-Date).Hour -ge 9 -and $lastDaily -ne $today) {
    Run-DailyAudit
  }

  Start-Sleep -Seconds 60
}

