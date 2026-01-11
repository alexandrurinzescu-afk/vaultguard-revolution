param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = "",

  [Parameter(Mandatory = $false)]
  [string]$RoadmapPath = "",

  [Parameter(Mandatory = $false)]
  [string]$OutQueueJson = "",

  [Parameter(Mandatory = $false)]
  [string]$OutQueueTxt = ""
)

# Parses roadmap checklist lines and produces:
# - task_queue.json (ordered tasks)
# - continuous_queue.txt (seed queue)
#
# NOTE: This parser only schedules executable "build/test" commands by default.
# Implementation tasks (writing code) still require developer action.

$ErrorActionPreference = "Stop"

function Ensure-Dir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
}

if ([string]::IsNullOrWhiteSpace($RoadmapPath)) {
  # Support common names
  $candidates = @(
    (Join-Path $ProjectRoot "VAULTGUARD_REVOLUTION_ROADMAP.md"),
    (Join-Path $ProjectRoot "VAULTGUARD_ROADMAP.md")
  )
  $RoadmapPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

if (-not $RoadmapPath -or -not (Test-Path -LiteralPath $RoadmapPath)) {
  throw "Roadmap file not found."
}

$trackDir = Join-Path $ProjectRoot "reports\\24_7_tracking"
Ensure-Dir $trackDir
Ensure-Dir (Join-Path $trackDir "checkpoint_backups")
Ensure-Dir (Join-Path $trackDir "logs")

if ([string]::IsNullOrWhiteSpace($OutQueueJson)) {
  $OutQueueJson = Join-Path $trackDir "task_queue.json"
}
if ([string]::IsNullOrWhiteSpace($OutQueueTxt)) {
  $OutQueueTxt = Join-Path $trackDir "continuous_queue.txt"
}

$raw = Get-Content -LiteralPath $RoadmapPath -Raw -ErrorAction Stop
# Match checklist task lines like: - [ ] 2.1.5 Something
# IMPORTANT: In PowerShell strings, backslash is not an escape character, so do NOT double-escape regex tokens.
$matches = [regex]::Matches($raw, "(?m)^-\s*\[\s*\]\s+(\d+\.\d+\.\d+)\b\s+(.+)$")
$pending = @()
foreach ($m in $matches) {
  $pending += [pscustomobject]@{
    subpoint = $m.Groups[1].Value.Trim()
    description = $m.Groups[2].Value.Trim()
  }
}

function Weight([string]$sp) {
  # Priority overrides: 2.1.5 first, then 2.5.*, then 5.1.*
  if ($sp -eq "2.1.5") { return 0 }
  if ($sp -like "2.5.*") { return 1 }
  if ($sp -like "5.1.*") { return 2 }
  return 10
}

$ordered = $pending | Sort-Object @{Expression={ Weight $_.subpoint }}, @{Expression={ $_.subpoint }}

# Build queue items:
# - We seed 2.1.5 with a "run unit tests" command (non-interactive).
# - Other items are placeholders (PAUSE) because they require code work.
$items = @()
foreach ($t in $ordered) {
  $cmd = "echo TODO: implement {0} - {1}" -f $t.subpoint, $t.description
  if ($t.subpoint -eq "2.1.5") {
    $cmd = ".\\gradlew.bat :app:testDebugUnitTest --no-daemon --console=plain"
  }
  $items += [pscustomobject]@{
    type = "TASK"
    subpoint = $t.subpoint
    description = $t.description
    command = $cmd
  }
}

$json = $items | ConvertTo-Json -Depth 6
$json | Out-File -FilePath $OutQueueJson -Encoding UTF8

$lines = @(
  "# Generated from: $RoadmapPath",
  "# Queue format: TASK|<Subpoint>|<Description>|<Command>",
  "# STOP to stop.",
  ""
)
foreach ($it in $items) {
  $lines += ("TASK|{0}|{1}|{2}" -f $it.subpoint, $it.description.Replace("|","/"), $it.command)
}
$lines | Out-File -FilePath $OutQueueTxt -Encoding UTF8

Write-Output ("OK: wrote {0}" -f $OutQueueJson)
Write-Output ("OK: wrote {0}" -f $OutQueueTxt)

