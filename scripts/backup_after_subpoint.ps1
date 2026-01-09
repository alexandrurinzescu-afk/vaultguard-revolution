param(
  [Parameter(Mandatory = $true)]
  [string]$Chapter,

  [Parameter(Mandatory = $true)]
  [string]$Subpoint,

  [Parameter(Mandatory = $true)]
  [string]$Description
)

# ASCII-only script (PowerShell 5.1 friendly)
$ErrorActionPreference = "Stop"

function Write-Info([string]$Msg) { Write-Host $Msg -ForegroundColor Cyan }
function Write-Ok([string]$Msg) { Write-Host $Msg -ForegroundColor Green }
function Write-Warn([string]$Msg) { Write-Host $Msg -ForegroundColor Yellow }
function Write-Err([string]$Msg) { Write-Host $Msg -ForegroundColor Red }

# Resolve project root from this script location: <repo>/scripts/backup_after_subpoint.ps1
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$backupDir = Join-Path $projectRoot "backups"
$roadmapFile = Join-Path $projectRoot "VAULTGUARD_REVOLUTION_ROADMAP.md"

if (-not (Test-Path -LiteralPath $roadmapFile)) {
  throw ("Roadmap file not found: {0}" -f $roadmapFile)
}

New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

Write-Info ("Project root: {0}" -f $projectRoot)
Write-Info ("Roadmap: {0}" -f $roadmapFile)
Write-Info ("Backups: {0}" -f $backupDir)

# 0) Protocol cleanup (ironclad workflow)
$protocolScript = Join-Path $PSScriptRoot "enforce_protocol.ps1"
if (Test-Path -LiteralPath $protocolScript) {
  Write-Info "Running protocol cleanup..."
  try {
    & $protocolScript -CurrentSubpoint $Subpoint -Operation "post-cleanup"
  } catch {
    Write-Err ("BACKUP BLOCKED: Protocol cleanup failed: {0}" -f $_.Exception.Message)
    exit 1
  }
} else {
  Write-Warn ("Protocol script not found (skipping): {0}" -f $protocolScript)
}

# 1) Update roadmap checkbox
$raw = Get-Content -LiteralPath $roadmapFile -Raw -ErrorAction Stop

# Enhanced dependency checking (sequential phases)
function Test-PhaseDependency {
  param(
    [Parameter(Mandatory = $true)][string]$Chapter,
    [Parameter(Mandatory = $true)][string]$Subpoint,
    [Parameter(Mandatory = $true)][string]$RoadmapText
  )

  $chapterMajor = ($Chapter -split "\\.")[0]

  function Test-GroupComplete([string]$prefix) {
    $any = ([regex]::Matches($RoadmapText, ("(?m)^- \\[[xX]\\] " + [regex]::Escape($prefix)))).Count
    $incomplete = ([regex]::Matches($RoadmapText, ("(?m)^- \\[(?![xX]\\])[^\\]]\\] " + [regex]::Escape($prefix)))).Count
    return ($any -gt 0) -and ($incomplete -eq 0)
  }

  # Chapter 3 sequential dependencies
  if ($chapterMajor -eq "3") {
    if ($Subpoint -match "^3\\.2") {
      if (-not (Test-GroupComplete "3.1.")) {
        Write-Err "BLOCKED: 3.2 requires 3.1 complete"
        return $false
      }
    }
    if ($Subpoint -match "^3\\.3") {
      if (-not (Test-GroupComplete "3.2.")) {
        Write-Err "BLOCKED: 3.3 requires 3.2 complete"
        return $false
      }
    }
    if ($Subpoint -match "^3\\.4") {
      if (-not (Test-GroupComplete "3.3.")) {
        Write-Err "BLOCKED: 3.4 requires 3.3 complete"
        return $false
      }
    }
  }

  # Chapter 7 requires Chapter 6 complete
  if ($chapterMajor -eq "7") {
    if (-not (Test-GroupComplete "6.")) {
      Write-Err "BLOCKED: Chapter 7 requires Chapter 6 complete"
      return $false
    }
  }

  return $true
}

# Enforce dependencies before modifying files / creating backups
if (-not (Test-PhaseDependency -Chapter $Chapter -Subpoint $Subpoint -RoadmapText $raw)) {
  Write-Err "CANNOT BACKUP: Dependencies not met"
  exit 1
}

# Match lines like: - [ ] 1.1.5 ...
# Allow any non-completed state marker (space, ~, !) and normalize to [x].
# Replace only the first match for the given subpoint.
$pattern = "(?m)^-\\s*\\[( |~|!)\\]\\s+" + [regex]::Escape($Subpoint) + "\\b"
if ($raw -match $pattern) {
  $raw2 = [regex]::Replace($raw, $pattern, ("- [x] " + $Subpoint), 1)
  Set-Content -LiteralPath $roadmapFile -Value $raw2 -Encoding UTF8
  Write-Ok ("Roadmap updated: marked {0} as completed." -f $Subpoint)
} else {
  Write-Warn ("Roadmap checkbox not found for subpoint {0}. No change made." -f $Subpoint)
}

# 2) Git commit + tag (best-effort)
if (Get-Command git -ErrorAction SilentlyContinue) {
  Push-Location $projectRoot
  try {
    $hasGit = Test-Path -LiteralPath (Join-Path $projectRoot ".git")
    if (-not $hasGit) {
      Write-Warn "Git not initialized in this repo. Skipping commit/tag."
    } else {
      git add -A | Out-Null
      $dirty = (git status --porcelain=v1 | Measure-Object).Count -gt 0
      if (-not $dirty) {
        Write-Warn "No changes detected for commit. Skipping commit/tag."
      } else {
        $commitMessage = ("OK [{0}.{1}] - {2}" -f $Chapter, $Subpoint, $Description)
        git commit -m $commitMessage | Out-Null

        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $tagName = ("v1.0-{0}-{1}-{2}" -f $Chapter, $Subpoint, $timestamp)
        git tag $tagName | Out-Null

        Write-Ok ("Git commit created + tag: {0}" -f $tagName)
      }
    }
  } catch {
    Write-Warn ("Git step failed (continuing): {0}" -f $_.Exception.Message)
  } finally {
    Pop-Location
  }
} else {
  Write-Warn "git command not found. Skipping commit/tag."
}

# 3) Create backup zip (exclude backups to avoid recursion)
$timestamp2 = Get-Date -Format "yyyyMMdd-HHmmss"
$safeSub = ($Subpoint -replace "[^0-9\\.]", "_")
$zipName = ("backup_{0}_{1}_{2}.zip" -f $Chapter, $safeSub, $timestamp2)
$zipPath = Join-Path $backupDir $zipName

Write-Info ("Creating zip: {0}" -f $zipPath)
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }

$items = Get-ChildItem -LiteralPath $projectRoot -Force |
  Where-Object { $_.Name -ne "backups" }

Compress-Archive -Path $items.FullName -DestinationPath $zipPath -CompressionLevel Optimal
Write-Ok ("Backup zip created: {0}" -f $zipPath)

# 4) Append activity log
$logPath = Join-Path $backupDir "activity_log.txt"
$log = @()
$log += ("DATE: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
$log += ("SUBPOINT: {0}.{1}" -f $Chapter, $Subpoint)
$log += ("DESC: {0}" -f $Description)
$log += ("ZIP: {0}" -f $zipPath)
$log += ""
Add-Content -LiteralPath $logPath -Value ($log -join "`r`n")

Write-Ok ("DONE: {0}.{1}" -f $Chapter, $Subpoint)

