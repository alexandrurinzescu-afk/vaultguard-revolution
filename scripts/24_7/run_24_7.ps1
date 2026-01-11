param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = "",

  [Parameter(Mandatory = $false)]
  [string]$QueueFile = "",

  [Parameter(Mandatory = $false)]
  [string]$ControlSignalFile = "",

  [Parameter(Mandatory = $false)]
  [int]$MaxRetries = 3
)

# Wrapper entrypoint to keep the requested structure under scripts/24_7/.
# Delegates to the repo root runner scripts/run_24_7.ps1.

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
$runner = Join-Path $repoRoot "scripts\\run_24_7.ps1"

if ([string]::IsNullOrWhiteSpace($QueueFile)) {
  $QueueFile = Join-Path $repoRoot "reports\\24_7_tracking\\task_queue.txt"
}
if ([string]::IsNullOrWhiteSpace($ControlSignalFile)) {
  $ControlSignalFile = Join-Path $repoRoot "reports\\24_7_tracking\\control_signal.txt"
}

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) { $ProjectRoot = $repoRoot }

& $runner -ProjectRoot $ProjectRoot -QueueFile $QueueFile -ControlSignalFile $ControlSignalFile -MaxRetries $MaxRetries
