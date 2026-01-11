param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = "",

  [Parameter(Mandatory = $false)]
  [int]$IntervalSeconds = 300,

  [Parameter(Mandatory = $false)]
  [string]$StopFile = "",

  [Parameter(Mandatory = $false)]
  [string]$PingHost = "1.1.1.1"
)

# Stability monitor for unattended sessions (PowerShell 5.1 friendly).
# Logs:
# - reports/stability.log (heartbeat: RAM + paging + ping)
# - reports/incidents/* (copies new hs_err_pid*.log)

$ErrorActionPreference = "Stop"

function Ensure-Dir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

$reportsDir = Join-Path $ProjectRoot "reports"
$incDir = Join-Path $reportsDir "incidents"
Ensure-Dir $reportsDir
Ensure-Dir $incDir

if ([string]::IsNullOrWhiteSpace($StopFile)) {
  $StopFile = Join-Path $reportsDir "STOP_CONTINUOUS.txt"
}

$logPath = Join-Path $reportsDir "stability.log"

function Snapshot-Line {
  $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $freeRamMB = "n/a"
  $pageMB = "n/a"
  $ping = "n/a"

  try {
    $os = Get-CimInstance Win32_OperatingSystem
    $freeRamMB = [int]([math]::Round($os.FreePhysicalMemory / 1024.0))
  } catch { }

  try {
    $pf = Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pf -and $pf.AllocatedBaseSize -ne $null) { $pageMB = [int]$pf.AllocatedBaseSize }
  } catch { }

  try {
    $ok = Test-Connection -ComputerName $PingHost -Count 1 -Quiet -ErrorAction SilentlyContinue
    $ping = $(if ($ok) { "OK" } else { "FAIL" })
  } catch { }

  return ("{0} | freeRamMB={1} | pagefileMB={2} | ping({3})={4}" -f $ts, $freeRamMB, $pageMB, $PingHost, $ping)
}

function Capture-New-HsErr {
  $hs = @(Get-ChildItem -LiteralPath $ProjectRoot -Filter "hs_err_pid*.log" -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 10)
  foreach ($f in $hs) {
    $dest = Join-Path $incDir $f.Name
    if (-not (Test-Path -LiteralPath $dest)) {
      Copy-Item -LiteralPath $f.FullName -Destination $dest -Force -ErrorAction SilentlyContinue
    }
  }
}

"START {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss") | Out-File -FilePath $logPath -Append -Encoding UTF8

while ($true) {
  if (Test-Path -LiteralPath $StopFile) {
    "STOP {0} (stop file detected)" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss") | Out-File -FilePath $logPath -Append -Encoding UTF8
    break
  }

  Snapshot-Line | Out-File -FilePath $logPath -Append -Encoding UTF8
  Capture-New-HsErr

  Start-Sleep -Seconds ([math]::Max(5, $IntervalSeconds))
}

