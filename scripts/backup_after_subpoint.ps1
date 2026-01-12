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
$protocol = Join-Path $PSScriptRoot "enforce_protocol.ps1"
$numericSubpoint = ($Subpoint -split "-", 2)[0]
$derivedChapter = ($numericSubpoint -replace "\.\d+$", "")
$chapterFinal = if (-not [string]::IsNullOrWhiteSpace($Chapter)) { $Chapter } else { $derivedChapter }

if (-not (Test-Path -LiteralPath $roadmapFile)) {
  throw ("Roadmap file not found: {0}" -f $roadmapFile)
}

New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

Write-Info ("Project root: {0}" -f $projectRoot)
Write-Info ("Roadmap: {0}" -f $roadmapFile)
Write-Info ("Backups: {0}" -f $backupDir)
Write-Info ("Subpoint: {0} (chapter: {1})" -f $numericSubpoint, $chapterFinal)

# 0) Protocol cleanup (mandatory): remove _temp_debug_* and verify clean.
if (Test-Path -LiteralPath $protocol) {
  try {
    & $protocol -CurrentSubpoint $Subpoint -Operation "post-cleanup" | Out-Null
  } catch {
    Write-Warn ("Protocol cleanup failed (continuing): {0}" -f $_.Exception.Message)
  }
} else {
  Write-Warn ("Protocol script missing (skipping cleanup): {0}" -f $protocol)
}

# 1) Update roadmap checkbox
$raw = Get-Content -LiteralPath $roadmapFile -Raw -ErrorAction Stop

# Match lines like: - [ ] 1.1.5 ...
# Replace only the first match for the given subpoint.
# IMPORTANT: In PowerShell strings, backslash is not an escape character, so do NOT double-escape regex tokens.
$pattern = "(?m)^\s*-\s*\[\s\]\s+" + [regex]::Escape($numericSubpoint) + "\b"
if ($raw -match $pattern) {
  $raw2 = [regex]::Replace($raw, $pattern, ("- [x] " + $numericSubpoint), 1)
  Set-Content -LiteralPath $roadmapFile -Value $raw2 -Encoding UTF8
  Write-Ok ("Roadmap updated: marked {0} as completed." -f $numericSubpoint)
} else {
  Write-Warn ("Roadmap checkbox not found for subpoint {0}. No change made." -f $numericSubpoint)
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
        $commitMessage = ("OK [{0}] - {1}" -f $numericSubpoint, $Description)
        git commit -m $commitMessage | Out-Null

        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $tagName = ("v1.0-{0}-{1}" -f $numericSubpoint, $timestamp)
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
$safeSub = ($numericSubpoint -replace "[^0-9\\.]", "_")
$zipName = ("backup_{0}_{1}_{2}.zip" -f $chapterFinal, $safeSub, $timestamp2)
$zipPath = Join-Path $backupDir $zipName

Write-Info ("Creating zip: {0}" -f $zipPath)
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }

function Test-IsExcludedForBackup([string]$FullPath) {
  $p = $FullPath.ToLowerInvariant()
  return (
    $p -like "*\\vaultguardrevolution\\.git\\*" -or
    $p -like "*\\vaultguardrevolution\\.gradle\\*" -or
    $p -like "*\\vaultguardrevolution\\.idea\\*" -or
    $p -like "*\\vaultguardrevolution\\app\\build\\*" -or
    $p -like "*\\vaultguardrevolution\\build\\*" -or
    $p -like "*\\vaultguardrevolution\\backups\\*" -or
    $p -like "*\\vaultguardrevolution\\reports\\*" -or
    $p -like "*\\vaultguardrevolution\\chat_history\\*" -or
    $p -like "*\\vaultguardrevolution\\.cxx\\*" -or
    $p -like "*\\vaultguardrevolution\\.kotlin\\*"
  )
}

$files = Get-ChildItem -LiteralPath $projectRoot -Recurse -File -Force |
  Where-Object { -not (Test-IsExcludedForBackup $_.FullName) }

function Compress-Archive-Safe([string]$DestinationZip, [int]$Attempts = 3) {
  $last = $null
  for ($i = 1; $i -le $Attempts; $i++) {
    try {
      # Re-enumerate right before zipping to reduce race conditions with build outputs.
      $fs = Get-ChildItem -LiteralPath $projectRoot -Recurse -File -Force |
        Where-Object { -not (Test-IsExcludedForBackup $_.FullName) } |
        Where-Object { Test-Path -LiteralPath $_.FullName }

      if (Test-Path -LiteralPath $DestinationZip) { Remove-Item -LiteralPath $DestinationZip -Force }
      Compress-Archive -Path $fs.FullName -DestinationPath $DestinationZip -CompressionLevel Optimal
      return
    } catch {
      $last = $_
      Start-Sleep -Seconds ([math]::Min(5, $i))
    }
  }
  throw $last
}

Compress-Archive-Safe -DestinationZip $zipPath -Attempts 3
Write-Ok ("Backup zip created: {0}" -f $zipPath)

# 4) Append activity log
$logPath = Join-Path $backupDir "activity_log.txt"
$log = @()
$log += ("DATE: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
$log += ("SUBPOINT: {0}" -f $numericSubpoint)
$log += ("DESC: {0}" -f $Description)
$log += ("ZIP: {0}" -f $zipPath)
$log += ""
Add-Content -LiteralPath $logPath -Value ($log -join "`r`n")

Write-Ok ("DONE: {0}" -f $numericSubpoint)

# 5) Start Cursor and open this repo (best-effort)
# Cautam Cursor in locatii comune
$cursorPaths = @(
  (Join-Path $env:ProgramFiles "Cursor\cursor.exe"),
  (Join-Path $env:LocalAppData "Programs\Cursor\cursor.exe"),
  (Join-Path $env:USERPROFILE "AppData\Local\Programs\Cursor\cursor.exe"),
  "C:\Program Files\Cursor\cursor.exe",
  "C:\Program Files (x86)\Cursor\cursor.exe"
)

$started = $false
foreach ($path in $cursorPaths) {
  if (Test-Path -LiteralPath $path) {
    try {
      Start-Process -FilePath $path -ArgumentList @($projectRoot) | Out-Null
      Write-Ok ("Cursor started from: {0}" -f $path)
      $started = $true
      break
    } catch {
      Write-Warn ("Failed to start Cursor from {0}: {1}" -f $path, $_.Exception.Message)
    }
  }
}

# Daca nu gasim, deschidem pagina de instalare
if (-not $started -and -not (Get-Process -Name "cursor" -ErrorAction SilentlyContinue)) {
  Write-Err "Cursor not found. Opening install page..."
  Start-Process "https://cursor.sh" | Out-Null
}