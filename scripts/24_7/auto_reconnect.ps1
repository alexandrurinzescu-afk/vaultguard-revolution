param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = "",

  [Parameter(Mandatory = $false)]
  [int]$MaxRetries = 5,

  [Parameter(Mandatory = $false)]
  [int]$InitialBackoffSeconds = 30
)

# Auto reconnect + resume launcher:
# - Ensures ConnectionMonitor is running
# - Ensures 24/7 runner is running
# - Uses exponential backoff on start failures
# - Writes logs to reports/24_7_tracking/logs/auto_reconnect.log

$ErrorActionPreference = "Stop"

function Ensure-Dir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function NowIso() { return (Get-Date -Format "yyyy-MM-dd HH:mm:ss") }

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
}

$trackDir = Join-Path $ProjectRoot "reports\\24_7_tracking"
$logsDir = Join-Path $trackDir "logs"
Ensure-Dir $trackDir
Ensure-Dir $logsDir

$logFile = Join-Path $logsDir "auto_reconnect.log"
$runnerPidFile = Join-Path $trackDir "runner.pid"
$monitorPidFile = Join-Path $trackDir "connection_monitor.pid"

function Append-Log([string]$msg) {
  Add-Content -LiteralPath $logFile -Value ("[{0}] {1}" -f (NowIso), $msg)
}

function Test-PidRunning([string]$pidFile) {
  if (-not (Test-Path -LiteralPath $pidFile)) { return $false }
  try {
    $pidVal = [int]((Get-Content -LiteralPath $pidFile -Raw -ErrorAction SilentlyContinue).Trim())
    if ($pidVal -le 0) { return $false }
    $p = Get-Process -Id $pidVal -ErrorAction SilentlyContinue
    return ($null -ne $p)
  } catch { return $false }
}

function Start-IfNotRunning([string]$name, [string]$pidFile, [string]$scriptPath, [string[]]$args) {
  if (Test-PidRunning $pidFile) {
    Append-Log ("{0} already running (pid file {1})" -f $name, $pidFile)
    return $true
  }

  $ps = Join-Path $env:WINDIR "System32\\WindowsPowerShell\\v1.0\\powershell.exe"
  $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $scriptPath) + $args
  Append-Log ("Starting {0}: {1} {2}" -f $name, $scriptPath, ($args -join " "))
  Start-Process -FilePath $ps -ArgumentList $argList -WorkingDirectory $ProjectRoot -WindowStyle Hidden | Out-Null
  Start-Sleep -Seconds 2
  return (Test-PidRunning $pidFile)
}

$monitorScript = Join-Path $ProjectRoot "scripts\\24_7\\connection_monitor.ps1"
$runnerScript = Join-Path $ProjectRoot "scripts\\24_7\\run_24_7.ps1"

$retry = 0
$backoff = $InitialBackoffSeconds

while ($true) {
  try {
    $okMon = Start-IfNotRunning -name "ConnectionMonitor" -pidFile $monitorPidFile -scriptPath $monitorScript -args @("-ProjectRoot", $ProjectRoot)
    $okRun = Start-IfNotRunning -name "Runner" -pidFile $runnerPidFile -scriptPath $runnerScript -args @("-ProjectRoot", $ProjectRoot)

    if ($okMon -and $okRun) {
      Append-Log "OK: monitor + runner running"
      break
    }

    throw "One or more components failed to start."
  } catch {
    $retry++
    Append-Log ("WARN: start failed ({0}/{1}): {2}" -f $retry, $MaxRetries, $_.Exception.Message)
    if ($retry -ge $MaxRetries) {
      Append-Log "ERROR: max retries reached; giving up."
      break
    }
    Append-Log ("Sleeping {0}s (backoff)" -f $backoff)
    Start-Sleep -Seconds $backoff
    $backoff = [math]::Min(1800, $backoff * 2)
  }
}

