# VAULTGUARD REVOLUTION - PROTOCOL ENFORCEMENT SYSTEM
# PowerShell 5.1 friendly, ASCII-only output.
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern("^\d+\.\d+\.\d+$")]
  [string]$CurrentSubpoint,

  [Parameter(Mandatory = $true)]
  [ValidateSet("pre-check", "post-cleanup", "verify")]
  [string]$Operation
)

$ErrorActionPreference = "Stop"

function Write-Info([string]$Msg) { Write-Host $Msg -ForegroundColor Cyan }
function Write-Ok([string]$Msg) { Write-Host $Msg -ForegroundColor Green }
function Write-Warn([string]$Msg) { Write-Host $Msg -ForegroundColor Yellow }
function Write-Err([string]$Msg) { Write-Host $Msg -ForegroundColor Red }

# Resolve project root from this script location: <repo>/scripts/enforce_protocol.ps1
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$roadmapFile = Join-Path $projectRoot "VAULTGUARD_REVOLUTION_ROADMAP.md"

if (-not (Test-Path -LiteralPath $roadmapFile)) {
  throw ("Roadmap file not found: {0}" -f $roadmapFile)
}

function Get-RoadmapText {
  return (Get-Content -LiteralPath $roadmapFile -Raw -ErrorAction Stop)
}

function Get-OrderedSubpoints([string]$RoadmapText) {
  # Captures the subpoint IDs in appearance order from checklist lines.
  # Example: - [ ] 3.2.4 Something
  $matches = [regex]::Matches($RoadmapText, "(?m)^- \[[ xX!~]\]\s+(\d+\.\d+\.\d+)\b")
  $list = @()
  foreach ($m in $matches) { $list += $m.Groups[1].Value }
  return $list
}

function Test-SubpointCompleted([string]$RoadmapText, [string]$Subpoint) {
  return ($RoadmapText -match ("(?m)^- \[[xX]\]\s+" + [regex]::Escape($Subpoint) + "\b"))
}

function Test-PreviousSubpointComplete {
  param([string]$Subpoint)

  $content = Get-RoadmapText
  $ordered = Get-OrderedSubpoints -RoadmapText $content

  $idx = [Array]::IndexOf($ordered, $Subpoint)
  if ($idx -lt 0) {
    Write-Err ("BLOCKED: Subpoint not found in roadmap: {0}" -f $Subpoint)
    return $false
  }
  if ($idx -eq 0) { return $true }

  $prev = $ordered[$idx - 1]
  if (-not (Test-SubpointCompleted -RoadmapText $content -Subpoint $prev)) {
    Write-Err ("BLOCKED: Previous subpoint not complete: {0} (required before {1})" -f $prev, $Subpoint)
    return $false
  }

  return $true
}

function Get-ExcludedRootRegex {
  # Exclude paths that commonly contain "debug" or temp-like artifacts but should NOT block workflow.
  # Case-insensitive.
  return "(?i)\\(\\.git|\\.gradle|\\.idea)\\|\\(app\\build\\)\\|\\(build\\)\\|\\(backups\\)\\|\\(reports\\)\\|\\(\\.cxx\\)\\|\\(\\.kotlin\\)"
}

function Cleanup-TempFiles {
  # Mandatory cleanup, but safe: only deletes protocol-managed temp folders + explicit temp marker files.
  $tempDirs = Get-ChildItem -LiteralPath $projectRoot -Directory -Filter "_temp_debug_*" -ErrorAction SilentlyContinue
  foreach ($d in $tempDirs) {
    try { Remove-Item -LiteralPath $d.FullName -Recurse -Force -ErrorAction Stop } catch { }
  }

  # Delete explicit temp marker files in repo root (NOT recursive) to avoid wiping useful build logs.
  $rootTempFiles = Get-ChildItem -LiteralPath $projectRoot -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match "(?i)(_temp\\.|\\.tmp$|\\.debug$)" }
  foreach ($f in $rootTempFiles) {
    try { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop } catch { }
  }

  Write-Ok "Cleaned protocol temp artifacts (_temp_debug_* + *_temp.* in repo root)."
}

function Verify-CleanProject {
  $exclude = Get-ExcludedRootRegex

  $tempDirs = Get-ChildItem -LiteralPath $projectRoot -Directory -Recurse -ErrorAction SilentlyContinue |
    Where-Object {
      $_.FullName -notmatch $exclude -and (
        $_.Name -match "(?i)^_temp_debug_" -or
        $_.Name -match "(?i)^temp$|^tmp$|^debug$" -or
        $_.Name -match "(?i)temp|debug"
      )
    }

  # Files are only a problem if they are protocol temp markers or true temp extensions.
  $tempFiles = Get-ChildItem -LiteralPath $projectRoot -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object {
      $_.FullName -notmatch $exclude -and (
        $_.Name -match "(?i)(_temp\\.)" -or
        $_.Extension -match "^(?i)\\.tmp$|\\.debug$"
      )
    }

  if (($tempFiles.Count -eq 0) -and ($tempDirs.Count -eq 0)) {
    Write-Ok "Project is clean (no protocol temp artifacts detected)."
    return $true
  }

  Write-Err "PROJECT NOT CLEAN!"
  foreach ($d in $tempDirs | Select-Object -First 50) { Write-Host ("  DIR:  {0}" -f $d.FullName) }
  foreach ($f in $tempFiles | Select-Object -First 50) { Write-Host ("  FILE: {0}" -f $f.FullName) }
  if ($tempDirs.Count -gt 50 -or $tempFiles.Count -gt 50) { Write-Warn "Output truncated (showing first 50 items)." }
  return $false
}

switch ($Operation) {
  "pre-check" {
    Write-Info ("PROTOCOL PRE-CHECK FOR: {0}" -f $CurrentSubpoint)

    if (-not (Test-PreviousSubpointComplete -Subpoint $CurrentSubpoint)) {
      exit 1
    }

    if (-not (Verify-CleanProject)) {
      Write-Err "BLOCKED: Project has protocol temp artifacts."
      exit 1
    }

    $currentTempDir = Join-Path $projectRoot ("_temp_debug_{0}" -f $CurrentSubpoint)
    New-Item -ItemType Directory -Force -Path $currentTempDir | Out-Null
    Write-Info ("Temp dir ready: {0}" -f $currentTempDir)

    Write-Ok ("PROTOCOL CHECK PASSED - Ready to implement {0}" -f $CurrentSubpoint)
  }

  "post-cleanup" {
    Write-Info ("PROTOCOL POST-CLEANUP FOR: {0}" -f $CurrentSubpoint)
    Cleanup-TempFiles
    if (-not (Verify-CleanProject)) { exit 1 }
  }

  "verify" {
    Write-Info "PROTOCOL VERIFICATION"
    if (-not (Verify-CleanProject)) { exit 1 }
  }
}

