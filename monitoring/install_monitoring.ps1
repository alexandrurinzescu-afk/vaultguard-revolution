param(
  [switch]$RegisterTasks,
  [switch]$DeployOnly
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\monitoring_common.ps1"

function Copy-MonitoringFiles {
  $dest = Get-MonitoringRoot
  Ensure-Directory $dest
  Ensure-Directory (Join-Path $dest "LOGS")
  Ensure-Directory (Join-Path $dest "BLOCKS")
  Ensure-Directory (Join-Path $dest "HOURLY_REPORTS")

  $files = @(
    "monitoring_common.ps1",
    "cursor_health_monitor.ps1",
    "recovery_orchestrator.ps1",
    "subpoint_execution_monitor.ps1",
    "hourly_intelligent_reporter.ps1",
    "execution_controller.ps1",
    "monitoring_launcher.ps1",
    "run_10min_test.ps1"
  )

  foreach ($f in $files) {
    $src = Join-Path $PSScriptRoot $f
    $dst = Join-Path $dest $f
    Copy-Item -LiteralPath $src -Destination $dst -Force
  }

  $readme = @()
  $readme += "VaultGuard Revolution - Monitoring"
  $readme += ("Deployed: {0}" -f (Get-Date))
  $readme += ""
  $readme += "Stop all monitors:"
  $readme += "  Create file: STOP_ALL.flag"
  $readme += ""
  $readme += "Logs:"
  $readme += "  LOGS\\*.log"
  Set-Content -LiteralPath (Join-Path $dest "README.txt") -Value ($readme -join "`r`n") -Encoding UTF8
}

function Install-StartupFallback {
  $dest = Get-MonitoringRoot
  $startup = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"
  Ensure-Directory $startup

  $cmdPath = Join-Path $startup "VaultGuardRevolution_Monitoring.cmd"
  $launcher = Join-Path $dest "monitoring_launcher.ps1"

  $lines = @()
  $lines += "@echo off"
  $lines += "REM VaultGuard Revolution Monitoring Auto-Start (User Startup Folder)"
  $lines += ('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $launcher)
  $lines += "exit /b 0"
  Set-Content -LiteralPath $cmdPath -Value ($lines -join "`r`n") -Encoding ASCII
  Write-Host ("Startup fallback installed: {0}" -f $cmdPath)
}

function Register-Task {
  param(
    [Parameter(Mandatory=$true)][string]$Name,
    [Parameter(Mandatory=$true)][string]$Args,
    [ValidateSet("ONLOGON","HOURLY","DAILY")][string]$Schedule = "ONLOGON"
  )

  $dest = Get-MonitoringRoot
  $ps = "powershell.exe"
  $taskName = "VGR-" + $Name
  $ru = $env:USERNAME

  # Always overwrite (use cmd redirection to avoid stderr becoming a terminating error in this environment)
  cmd /c "schtasks /Query /TN $taskName >nul 2>nul" | Out-Null
  if ($LASTEXITCODE -eq 0) {
    cmd /c "schtasks /Delete /TN $taskName /F >nul 2>nul" | Out-Null
  }

  if ($Schedule -eq "ONLOGON") {
    $out = cmd /c ("schtasks /Create /TN {0} /SC ONLOGON /RL LIMITED /IT /RU ""{1}"" /TR ""{2} {3}"" /F 2>&1" -f $taskName, $ru, $ps, $Args)
  } elseif ($Schedule -eq "HOURLY") {
    $out = cmd /c ("schtasks /Create /TN {0} /SC HOURLY /MO 1 /RL LIMITED /IT /RU ""{1}"" /TR ""{2} {3}"" /F 2>&1" -f $taskName, $ru, $ps, $Args)
  } elseif ($Schedule -eq "DAILY") {
    $out = cmd /c ("schtasks /Create /TN {0} /SC DAILY /ST 09:00 /RL LIMITED /IT /RU ""{1}"" /TR ""{2} {3}"" /F 2>&1" -f $taskName, $ru, $ps, $Args)
  }

  if ($LASTEXITCODE -ne 0) {
    throw ("Failed to create task {0}. Output: {1}" -f $taskName, ($out -join " "))
  }
}

Copy-MonitoringFiles
Write-Host ("Monitoring deployed to: {0}" -f (Get-MonitoringRoot))

if ($DeployOnly) { exit 0 }

if ($RegisterTasks) {
  $root = Get-MonitoringRoot
  try {
    Register-Task -Name "CursorHealthMonitor" -Schedule "ONLOGON" -Args ("-NoProfile -ExecutionPolicy Bypass -File ""{0}""" -f (Join-Path $root "cursor_health_monitor.ps1"))
    Register-Task -Name "ExecutionController" -Schedule "ONLOGON" -Args ("-NoProfile -ExecutionPolicy Bypass -File ""{0}""" -f (Join-Path $root "execution_controller.ps1"))
    Register-Task -Name "HourlyReporter" -Schedule "HOURLY" -Args ("-NoProfile -ExecutionPolicy Bypass -File ""{0}""" -f (Join-Path $root "hourly_intelligent_reporter.ps1"))

    # Daily protocol audit (from repo, already exists)
    $audit = Join-Path (Get-ProjectRoot) "scripts\daily_protocol_audit.ps1"
    if (Test-Path -LiteralPath $audit) {
      Register-Task -Name "DailyProtocolAudit" -Schedule "DAILY" -Args ("-NoProfile -ExecutionPolicy Bypass -File ""{0}""" -f $audit)
    }

    Write-Host "Scheduled tasks registered: VGR-*"
  } catch {
    Write-Host ("Scheduled tasks could not be registered (will use Startup fallback). Reason: {0}" -f $_.Exception.Message)
    Install-StartupFallback
  }
}

