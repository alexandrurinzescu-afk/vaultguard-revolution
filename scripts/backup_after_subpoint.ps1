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

# 1) Update roadmap checkbox
$raw = Get-Content -LiteralPath $roadmapFile -Raw -ErrorAction Stop

# Match lines like: - [ ] 1.1.5 ...
# Replace only the first match for the given subpoint.
$pattern = "(?m)^- \\[ \\] " + [regex]::Escape($Subpoint) + "\\b"
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
$timestamp = $timestamp2
$safeSub = ($Subpoint -replace "[^0-9\\.]", "_")
$zipName = ("backup_{0}_{1}_{2}.zip" -f $Chapter, $safeSub, $timestamp2)
$zipPath = Join-Path $backupDir $zipName

Write-Info ("Creating zip: {0}" -f $zipPath)
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }

$items = Get-ChildItem -LiteralPath $projectRoot -Force |
  Where-Object { $_.Name -ne "backups" }

Compress-Archive -Path $items.FullName -DestinationPath $zipPath -CompressionLevel Optimal
Write-Ok ("Backup zip created: {0}" -f $zipPath)

# Special handling for hardware integration milestones (Chapter 3.x)
if ($Chapter -match "3\\.[1-5]") {
  Write-Host "HARDWARE MILESTONE - CREATING EXTENDED BACKUP" -ForegroundColor Magenta

  $hardwareBackupDir = Join-Path $backupDir ("hardware_integration_{0}" -f $timestamp)
  New-Item -ItemType Directory -Path $hardwareBackupDir -Force | Out-Null

  $libsDst = Join-Path $hardwareBackupDir "libs"
  $jniDst = Join-Path $hardwareBackupDir "jniLibs"

  if (Test-Path -LiteralPath $libsDst) { } else { New-Item -ItemType Directory -Path $libsDst -Force | Out-Null }
  if (Test-Path -LiteralPath $jniDst) { } else { New-Item -ItemType Directory -Path $jniDst -Force | Out-Null }

  if (Test-Path -LiteralPath (Join-Path $projectRoot "app\\libs")) {
    Copy-Item (Join-Path $projectRoot "app\\libs\\*") $libsDst -Recurse -Force -ErrorAction SilentlyContinue
  }
  if (Test-Path -LiteralPath (Join-Path $projectRoot "app\\src\\main\\jniLibs")) {
    Copy-Item (Join-Path $projectRoot "app\\src\\main\\jniLibs\\*") $jniDst -Recurse -Force -ErrorAction SilentlyContinue
  }

  Write-Host ("Hardware files backed up to: {0}" -f $hardwareBackupDir) -ForegroundColor Cyan
}

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

