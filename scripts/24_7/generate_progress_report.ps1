param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = "",

  [Parameter(Mandatory = $false)]
  [string]$RoadmapPath = "",

  [Parameter(Mandatory = $false)]
  [int]$NextQueueCount = 5
)

# Generates a complete progress report by combining:
# - Roadmap checklist status (COMPLETED / PENDING / BLOCKED)
# - 24/7 runner history (reports/24_7_tracking/progress.csv)
# - Admin blockers (reports/24_7_tracking/admin_blockers.md)
# - Current queue (reports/24_7_tracking/task_queue.txt)
#
# Output:
# - reports/progress_report_<timestamp>.md
# - Prints a compact summary to console
#
# PowerShell 5.1 friendly.

$ErrorActionPreference = "Stop"

function NowIso() { return (Get-Date -Format "yyyy-MM-dd HH:mm:ss") }
function NowTs() { return (Get-Date -Format "yyyyMMdd_HHmmss") }
function Invariant() { return [System.Globalization.CultureInfo]::InvariantCulture }
function FmtDouble([double]$d) { return ([math]::Round([double]$d, 2)).ToString((Invariant)) }

function Resolve-RepoRoot() {
  if (-not [string]::IsNullOrWhiteSpace($ProjectRoot)) {
    return (Resolve-Path -LiteralPath $ProjectRoot).Path
  }
  return (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}

function Parse-Roadmap([string]$path) {
  $text = Get-Content -LiteralPath $path -Raw -ErrorAction Stop
  $pattern = '(?m)^\s*-\s*\[([ xX!])\]\s+(\d+\.\d+\.\d+)\s+(.*)$'
  $ms = [regex]::Matches($text, $pattern)
  $items = @()
  foreach ($m in $ms) {
    $mark = $m.Groups[1].Value
    $id = $m.Groups[2].Value.Trim()
    $desc = $m.Groups[3].Value.Trim()
    $status = "PENDING"
    if ($mark -match '^[xX]$') { $status = "COMPLETED" }
    elseif ($mark -eq '!') { $status = "BLOCKED" }
    $items += [pscustomobject]@{
      subpoint = $id
      description = $desc
      status = $status
    }
  }
  return $items
}

function Try-ParseDoubleInvariant([string]$s) {
  if ([string]::IsNullOrWhiteSpace($s)) { return $null }
  try {
    return [double]::Parse($s, [System.Globalization.CultureInfo]::InvariantCulture)
  } catch {
    try { return [double]$s } catch { return $null }
  }
}

function Parse-ProgressCsv([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return @() }
  $rows = Import-Csv -LiteralPath $path -ErrorAction Stop
  $out = @()
  foreach ($r in $rows) {
    $dur = Try-ParseDoubleInvariant ([string]$r.DurationSeconds)
    $out += [pscustomobject]@{
      Timestamp = [string]$r.Timestamp
      Task = [string]$r.Task
      Status = [string]$r.Status
      DurationSeconds = $dur
      Notes = [string]$r.Notes
    }
  }
  return $out
}

function Load-Queue([string]$path, [int]$n) {
  if (-not (Test-Path -LiteralPath $path)) { return @() }
  $lines = @(Get-Content -LiteralPath $path -ErrorAction SilentlyContinue) | ForEach-Object { [string]$_ }
  $lines = @($lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  if ($lines.Count -le 0) { return @() }
  if ($n -lt 1) { $n = 5 }
  return @($lines | Select-Object -First $n)
}

function Score([string]$id) {
  if ($id -eq "2.1.5") { return 0 }
  if ($id -like "2.5.*") { return 1 }
  return 2
}

function Planned-Next([object[]]$roadmapItems, [int]$n) {
  if ($n -lt 1) { $n = 5 }
  $pending = @($roadmapItems | Where-Object { $_.status -eq "PENDING" })
  if ($pending.Count -le 0) { return @() }
  $ordered = $pending | Sort-Object @{Expression={ Score $_.subpoint }; Ascending=$true}, @{Expression={ $_.subpoint }; Ascending=$true}
  return @($ordered | Select-Object -First $n)
}

function Read-AdminBlockers([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return @() }
  $lines = @(Get-Content -LiteralPath $path -ErrorAction SilentlyContinue) | ForEach-Object { [string]$_ }
  # Heuristic: treat markdown list items as blockers
  return @($lines | Where-Object { $_.TrimStart().StartsWith("- ") })
}

$repoRoot = Resolve-RepoRoot
Set-Location -LiteralPath $repoRoot

if ([string]::IsNullOrWhiteSpace($RoadmapPath)) {
  $candidate1 = Join-Path $repoRoot "VAULTGUARD_REVOLUTION_ROADMAP.md"
  $candidate2 = Join-Path $repoRoot "VAULTGUARD_ROADMAP.md"
  if (Test-Path -LiteralPath $candidate1) { $RoadmapPath = $candidate1 }
  elseif (Test-Path -LiteralPath $candidate2) { $RoadmapPath = $candidate2 }
  else { throw "No roadmap file found (tried VAULTGUARD_REVOLUTION_ROADMAP.md, VAULTGUARD_ROADMAP.md). Provide -RoadmapPath." }
} else {
  $RoadmapPath = (Resolve-Path -LiteralPath $RoadmapPath).Path
}

$trackingDir = Join-Path $repoRoot "reports\24_7_tracking"
$progressCsv = Join-Path $trackingDir "progress.csv"
$adminBlockersMd = Join-Path $trackingDir "admin_blockers.md"
$queueFile = Join-Path $trackingDir "task_queue.txt"
$controlSignalFile = Join-Path $trackingDir "control_signal.txt"
$currentTaskFile = Join-Path $trackingDir "current_task.json"

$roadmapItems = Parse-Roadmap -path $RoadmapPath
$progressRows = Parse-ProgressCsv -path $progressCsv
$nextQueue = Load-Queue -path $queueFile -n $NextQueueCount
$blockers = Read-AdminBlockers -path $adminBlockersMd

$completed = @($roadmapItems | Where-Object { $_.status -eq "COMPLETED" })
$blocked = @($roadmapItems | Where-Object { $_.status -eq "BLOCKED" })
$pending = @($roadmapItems | Where-Object { $_.status -eq "PENDING" })

$inProgress = @()
if (Test-Path -LiteralPath $currentTaskFile) {
  try {
    $ct = (Get-Content -LiteralPath $currentTaskFile -Raw -ErrorAction SilentlyContinue)
    if ($ct) {
      $obj = $ct | ConvertFrom-Json -ErrorAction SilentlyContinue
      if ($obj -and $obj.status -eq "IN_PROGRESS") {
        $inProgress += [pscustomobject]@{
          subpoint = [string]$obj.subpoint
          description = [string]$obj.description
          startedAt = [string]$obj.startedAt
        }
      }
    }
  } catch { }
}

$total = $roadmapItems.Count
$pct = 0
if ($total -gt 0) { $pct = [math]::Round((100.0 * $completed.Count / $total), 1) }
$pctStr = ([double]$pct).ToString((Invariant))

$totalWorkSeconds = 0.0
foreach ($r in $progressRows) {
  if ($null -ne $r.DurationSeconds) { $totalWorkSeconds += [double]$r.DurationSeconds }
}
$totalWorkSecondsStr = FmtDouble $totalWorkSeconds

$taskDurations = @{}
foreach ($r in $progressRows) {
  if ([string]::IsNullOrWhiteSpace($r.Task)) { continue }
  if ($null -eq $r.DurationSeconds) { continue }
  if (-not $taskDurations.ContainsKey($r.Task)) { $taskDurations[$r.Task] = 0.0 }
  $taskDurations[$r.Task] = [double]$taskDurations[$r.Task] + [double]$r.DurationSeconds
}

$controlSignal = ""
if (Test-Path -LiteralPath $controlSignalFile) {
  $controlSignal = ((Get-Content -LiteralPath $controlSignalFile -Raw -ErrorAction SilentlyContinue) -as [string])
  if ($controlSignal) { $controlSignal = $controlSignal.Trim() } else { $controlSignal = "" }
}

$reportsDir = Join-Path $repoRoot "reports"
if (-not (Test-Path -LiteralPath $reportsDir)) { New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null }
$outPath = Join-Path $reportsDir ("progress_report_{0}.md" -f (NowTs))

$plannedNext = Planned-Next -roadmapItems $roadmapItems -n $NextQueueCount

$lines = @()
$lines += "VAULTGUARD REVOLUTION - PROGRESS REPORT"
$lines += ("Generated: {0}" -f (NowIso))
$lines += ""
$lines += "Roadmap: $RoadmapPath"
$lines += ("Runner history: {0}" -f $progressCsv)
$lines += ""
$lines += "EXECUTION SUMMARY:"
$lines += ("- Total tasks in roadmap: {0}" -f $total)
$lines += ("- Completed: {0} ({1}%)" -f $completed.Count, $pctStr)
$lines += ("- In Progress: {0}" -f $inProgress.Count)
$lines += ("- Blocked: {0}" -f $blocked.Count)
$lines += ("- Pending: {0}" -f $pending.Count)
$lines += ""
$lines += "COMPLETED TASKS:"
if ($completed.Count -eq 0) {
  $lines += "- (none)"
} else {
  $i = 1
  foreach ($t in $completed | Sort-Object subpoint) {
    $dur = "n/a"
    if ($taskDurations.ContainsKey($t.subpoint)) {
      $dur = ("{0}s" -f (FmtDouble ([double]$taskDurations[$t.subpoint])))
    }
    $lines += ("{0}. [x] {1} - {2} (Duration: {3})" -f $i, $t.subpoint, $t.description, $dur)
    $i++
  }
}
$lines += ""
$lines += "IN PROGRESS:"
if ($inProgress.Count -eq 0) {
  $lines += "- (none)"
} else {
  $i = 1
  foreach ($t in $inProgress) {
    $lines += ("{0}. [IN_PROGRESS] {1} - {2} (Started: {3})" -f $i, $t.subpoint, $t.description, $t.startedAt)
    $i++
  }
}
$lines += ""
$lines += "BLOCKED/PAUSED:"
if (-not [string]::IsNullOrWhiteSpace($controlSignal)) {
  $lines += ("- Control signal: {0}" -f $controlSignal)
}
if ($blocked.Count -eq 0 -and $blockers.Count -eq 0 -and [string]::IsNullOrWhiteSpace($controlSignal)) {
  $lines += "- (none)"
} else {
  if ($blocked.Count -gt 0) {
    $i = 1
    foreach ($t in $blocked | Sort-Object subpoint) {
      $lines += ("{0}. [BLOCKED] {1} - {2}" -f $i, $t.subpoint, $t.description)
      $i++
    }
  }
  if ($blockers.Count -gt 0) {
    $lines += ""
    $lines += "Admin blockers (from admin_blockers.md):"
    foreach ($b in $blockers) { $lines += ("- {0}" -f $b.Trim()) }
  }
}
$lines += ""
$lines += "NEXT IN QUEUE:"
if ($nextQueue.Count -eq 0) {
  $lines += "- (queue empty)"
} else {
  $i = 1
  foreach ($q in $nextQueue) {
    $lines += ("{0}. {1}" -f $i, $q)
    $i++
  }
}
$lines += ""
$lines += "NEXT PLANNED (if queue is empty):"
if ($plannedNext.Count -eq 0) {
  $lines += "- (none)"
} else {
  $i = 1
  foreach ($t in $plannedNext) {
    $lines += ("{0}. {1} - {2}" -f $i, $t.subpoint, $t.description)
    $i++
  }
}
$lines += ""
$lines += "TIME STATISTICS:"
$lines += ("- Total work time (from progress.csv): {0}s" -f $totalWorkSecondsStr)
$avg = "n/a"
if ($progressRows.Count -gt 0) {
  $avg = ("{0}s" -f (FmtDouble ($totalWorkSeconds / [double]$progressRows.Count)))
}
$lines += ("- Average per recorded run: {0}" -f $avg)
$lines += ""
$lines += "RECOMMENDED NEXT STEP:"
if ($nextQueue.Count -gt 0) {
  $lines += ("- Execute next queued item: {0}" -f $nextQueue[0])
} else {
  if ($plannedNext.Count -gt 0) {
    $lines += ("- Refill the queue; recommended next: {0} - {1}" -f $plannedNext[0].subpoint, $plannedNext[0].description)
  } else {
    $lines += "- Refill the queue (roadmap_parser.ps1) and ensure it emits executable lines (e.g., 2.1.5 VERIFY)."
  }
}

$lines += ""
$lines += "EXECUTION HISTORY (last 20 runs from progress.csv):"
if ($progressRows.Count -eq 0) {
  $lines += "- (none)"
} else {
  $recent = @($progressRows | Select-Object -Last 20)
  foreach ($r in $recent) {
    $dur = "n/a"
    if ($null -ne $r.DurationSeconds) { $dur = (FmtDouble ([double]$r.DurationSeconds)) + "s" }
    $lines += ("- {0} | {1} | {2} | {3} | {4}" -f $r.Timestamp, $r.Task, $r.Status, $dur, $r.Notes)
  }
}

$lines += ""
$lines += "FULL ROADMAP STATUS (per task):"
$lines += ""
$lines += "| Subpoint | Status | DurationSeconds (recorded) | Description |"
$lines += "|---|---|---:|---|"
foreach ($t in ($roadmapItems | Sort-Object subpoint)) {
  $durVal = ""
  if ($taskDurations.ContainsKey($t.subpoint)) { $durVal = FmtDouble ([double]$taskDurations[$t.subpoint]) } else { $durVal = "" }
  $lines += ("| {0} | {1} | {2} | {3} |" -f $t.subpoint, $t.status, $durVal, ($t.description -replace '\|', '\\|'))
}

$lines | Out-File -FilePath $outPath -Encoding UTF8

# Console summary (compact)
Write-Host "VAULTGUARD REVOLUTION - PROGRESS REPORT" -ForegroundColor Cyan
Write-Host ("Generated: {0}" -f (NowIso)) -ForegroundColor DarkGray
Write-Host ""
Write-Host "EXECUTION SUMMARY:" -ForegroundColor Cyan
Write-Host ("- Total tasks: {0}" -f $total)
Write-Host ("- Completed: {0} ({1}%)" -f $completed.Count, $pctStr)
Write-Host ("- In Progress: {0}" -f $inProgress.Count)
Write-Host ("- Blocked: {0}" -f $blocked.Count)
Write-Host ("- Pending: {0}" -f $pending.Count)
Write-Host ""
Write-Host "NEXT IN QUEUE:" -ForegroundColor Cyan
if ($nextQueue.Count -eq 0) { Write-Host "- (queue empty)" } else { $nextQueue | ForEach-Object { Write-Host ("- {0}" -f $_) } }
Write-Host ""
if ($nextQueue.Count -eq 0) {
  Write-Host "NEXT PLANNED:" -ForegroundColor Cyan
  if ($plannedNext.Count -eq 0) { Write-Host "- (none)" } else { $plannedNext | ForEach-Object { Write-Host ("- {0} - {1}" -f $_.subpoint, $_.description) } }
  Write-Host ""
}
Write-Host ("Report written: {0}" -f $outPath) -ForegroundColor Green

