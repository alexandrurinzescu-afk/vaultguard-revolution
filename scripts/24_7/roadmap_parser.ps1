param(
  [Parameter(Mandatory = $false)]
  [string]$RoadmapPath = "",

  [Parameter(Mandatory = $false)]
  [string]$OutJson = "",

  [Parameter(Mandatory = $false)]
  [string]$OutQueue = ""
)

# Roadmap parser: extract remaining subpoints from VAULTGUARD_REVOLUTION_ROADMAP.md into task_queue.json.
# Also produces a simple queue file (task_queue.txt) for the 24/7 runner.
# PowerShell 5.1 friendly.

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
if ([string]::IsNullOrWhiteSpace($RoadmapPath)) {
  $RoadmapPath = Join-Path $repoRoot "VAULTGUARD_REVOLUTION_ROADMAP.md"
}
if ([string]::IsNullOrWhiteSpace($OutJson)) {
  $OutJson = Join-Path $repoRoot "reports\\24_7_tracking\\task_queue.json"
}
if ([string]::IsNullOrWhiteSpace($OutQueue)) {
  $OutQueue = Join-Path $repoRoot "reports\\24_7_tracking\\task_queue.txt"
}

if (-not (Test-Path -LiteralPath $RoadmapPath)) {
  throw ("Roadmap not found: {0}" -f $RoadmapPath)
}

function Ensure-Dir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
Ensure-Dir (Split-Path -Parent $OutJson)

$text = Get-Content -LiteralPath $RoadmapPath -Raw -ErrorAction Stop

# Parse checklist lines: - [ ] 2.1.5 Something
$pattern = '(?m)^- \[([ xX!])\]\s+(\d+\.\d+\.\d+)\s+(.*)$'
$matches = [regex]::Matches($text, $pattern)
$items = @()
foreach ($m in $matches) {
  $state = $m.Groups[1].Value
  $id = $m.Groups[2].Value.Trim()
  $desc = $m.Groups[3].Value.Trim()
  $done = ($state -match "^[xX]$")
  if (-not $done) {
    $items += [pscustomobject]@{
      subpoint = $id
      description = $desc
      status = "PENDING"
    }
  }
}

# Priority: ensure 2.1.5 first if present, then 2.5.* (GDPR/privacy), then everything else in appearance order.
function Score([string]$id) {
  if ($id -eq "2.1.5") { return 0 }
  if ($id -like "2.5.*") { return 1 }
  return 2
}

$ordered = $items | Sort-Object @{Expression={ Score $_.subpoint }; Ascending=$true}, @{Expression={ $_.subpoint }; Ascending=$true}

# Build queue (safe default commands):
# - For 2.1.5 we run unit tests (will not complete the roadmap item; only validates current suite).
# - For others we leave CMD as empty so user fills in; runner will idle if queue has no executable lines.
$queueLines = @()
foreach ($it in $ordered) {
  if ($it.subpoint -eq "2.1.5") {
    $queueLines += ("TASK|{0}|{1}|cmd /d /c .\\gradlew.bat :app:testDebugUnitTest --no-daemon --console=plain" -f $it.subpoint, $it.description)
  }
}

$jsonObj = [pscustomobject]@{
  generatedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  roadmap = $RoadmapPath
  pending = $ordered
}

$jsonObj | ConvertTo-Json -Depth 6 | Out-File -FilePath $OutJson -Encoding UTF8
($queueLines -join "`r`n") | Out-File -FilePath $OutQueue -Encoding UTF8

Write-Output ("WROTE_JSON={0}" -f $OutJson)
Write-Output ("WROTE_QUEUE={0}" -f $OutQueue)
