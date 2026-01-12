param(
  [Parameter(Mandatory = $false)]
  [string]$RoadmapPath = "",

  [Parameter(Mandatory = $false)]
  [string]$OutJson = "",

  [Parameter(Mandatory = $false)]
  [string]$OutQueue = "",

  [Parameter(Mandatory = $false)]
  [ValidateRange(1, 200)]
  [int]$MaxQueueItems = 10
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

function Write-TextWithRetry([string]$Path, [string]$Text, [int]$Attempts = 5, [int]$SleepMs = 250) {
  $last = $null
  for ($i = 1; $i -le $Attempts; $i++) {
    try {
      $Text | Out-File -FilePath $Path -Encoding UTF8 -Force
      return
    } catch {
      $last = $_
      Start-Sleep -Milliseconds $SleepMs
    }
  }
  throw $last
}

# Parse checklist lines: - [ ] 2.1.5 Something
# (Allow leading whitespace to be resilient.)
$pattern = '(?m)^\s*-\s*\[([ xX!])\]\s+(\d+\.\d+\.\d+)\s+(.*)$'
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
# - Use VERIFY lines so the runner logs execution but does NOT mark roadmap complete.
# - For 2.1.5 we run unit tests (non-interactive).
# - For everything else we emit a harmless "manual reminder" VERIFY task so the queue is never empty.
#   (These DO NOT update the roadmap because they are VERIFY, not TASK.)
$queueLines = @()
foreach ($it in ($ordered | Select-Object -First $MaxQueueItems)) {
  $sp = [string]$it.subpoint
  $ds = [string]$it.description
  if ($sp -eq "2.1.5") {
    # Real checkpoint task: run unit tests, then runner will execute backup_after_subpoint (roadmap + git + zip).
    $queueLines += ("TASK|{0}|{1}|cmd /d /c .\\gradlew.bat :app:testDebugUnitTest --no-daemon --console=plain" -f $sp, $ds)
    continue
  }
  # Implementation placeholder: keeps the system moving without marking roadmap complete.
  # IMPORTANT: do NOT echo the full description (may contain cmd.exe metacharacters like & | ( ) < >)
  $safeMsg = ("MANUAL_TASK_REQUIRED_{0}" -f $sp)
  $queueLines += ("IMPLEMENT|{0}|{1}|cmd /d /c echo {2} & exit /b 0" -f $sp, $ds, $safeMsg)
}

$jsonObj = [pscustomobject]@{
  generatedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  roadmap = $RoadmapPath
  pending = $ordered
}

Write-TextWithRetry -Path $OutJson -Text ($jsonObj | ConvertTo-Json -Depth 6)
Write-TextWithRetry -Path $OutQueue -Text ($queueLines -join "`r`n")

Write-Output ("WROTE_JSON={0}" -f $OutJson)
Write-Output ("WROTE_QUEUE={0}" -f $OutQueue)
