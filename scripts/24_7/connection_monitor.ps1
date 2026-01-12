param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = "",

  [Parameter(Mandatory = $false)]
  [int]$IntervalSeconds = 300,

  [Parameter(Mandatory = $false)]
  [string[]]$Hosts = @("1.1.1.1", "github.com", "api.openai.com")
)

# Connection monitor:
# - Periodically checks network reachability.
# - If offline: writes PAUSE to reports/24_7_tracking/control_signal.txt
# - If back online: clears PAUSE (only if PAUSE was set)
# - Writes status to reports/24_7_tracking/connection_status.json and logs to reports/24_7_tracking/logs/connection_monitor.log

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

$pidFile = Join-Path $trackDir "connection_monitor.pid"
$control = Join-Path $trackDir "control_signal.txt"
$statusJson = Join-Path $trackDir "connection_status.json"
$logFile = Join-Path $logsDir "connection_monitor.log"

Set-Content -LiteralPath $pidFile -Value $PID -Encoding ASCII

function Append-Log([string]$msg) {
  Add-Content -LiteralPath $logFile -Value ("[{0}] {1}" -f (NowIso), $msg)
}

function Is-Online {
  foreach ($h in $Hosts) {
    try {
      if ($h -match "^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$") {
        if (Test-Connection -ComputerName $h -Count 1 -Quiet -ErrorAction SilentlyContinue) { return $true }
      } else {
        # Prefer TCP 443 where possible; fall back to ping.
        $tnc = Test-NetConnection -ComputerName $h -Port 443 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        if ($tnc -and $tnc.TcpTestSucceeded) { return $true }
        if (Test-Connection -ComputerName $h -Count 1 -Quiet -ErrorAction SilentlyContinue) { return $true }
      }
    } catch { }
  }
  return $false
}

$pausedByMonitor = $false
Append-Log ("START interval={0}s hosts={1}" -f $IntervalSeconds, ($Hosts -join ","))

while ($true) {
  $online = Is-Online

  $statusObj = [pscustomobject]@{
    timestamp = (NowIso)
    online = $online
    hosts = $Hosts
    pausedByMonitor = $pausedByMonitor
  }
  try { ($statusObj | ConvertTo-Json -Depth 4) | Out-File -FilePath $statusJson -Encoding UTF8 } catch { }

  try {
    $sig = [string](Get-Content -LiteralPath $control -Raw -ErrorAction SilentlyContinue)
    $sigU = $sig.ToUpperInvariant()

    if (-not $online) {
      if (-not $sigU.Contains("STOP")) {
        if (-not $sigU.Contains("PAUSE")) {
          "PAUSE" | Out-File -FilePath $control -Encoding ASCII
          $pausedByMonitor = $true
          Append-Log "OFFLINE -> wrote PAUSE"
        }
      }
    } else {
      if ($pausedByMonitor -and $sigU.Contains("PAUSE") -and (-not $sigU.Contains("STOP"))) {
        "" | Out-File -FilePath $control -Encoding ASCII
        $pausedByMonitor = $false
        Append-Log "ONLINE -> cleared PAUSE"
      }
    }
  } catch { }

  Start-Sleep -Seconds $IntervalSeconds
}

