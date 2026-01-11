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

# Wrapper entrypoint for the 24/7 workflow runner.
# Delegates to the repo-level implementation: scripts/run_24_7.ps1

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
}

if ([string]::IsNullOrWhiteSpace($QueueFile)) {
  $QueueFile = Join-Path $ProjectRoot "reports\\24_7_tracking\\continuous_queue.txt"
}
if ([string]::IsNullOrWhiteSpace($ControlSignalFile)) {
  $ControlSignalFile = Join-Path $ProjectRoot "reports\\24_7_tracking\\control_signal.txt"
}

$impl = Join-Path $ProjectRoot "scripts\\run_24_7.ps1"

& $impl -ProjectRoot $ProjectRoot -QueueFile $QueueFile -ControlSignalFile $ControlSignalFile -MaxRetries $MaxRetries

