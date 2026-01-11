param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = "C:\Users\pc\AndroidStudioProjects\VaultGuard",

  [Parameter(Mandatory = $false)]
  [string]$BackupRoot = "C:\Backup\VaultGuard",

  [Parameter(Mandatory = $false)]
  [switch]$SkipBackup,

  [Parameter(Mandatory = $false)]
  [switch]$OpenAfter
)

# Phase 1: Version control + docs scaffold (safe defaults)
# - No destructive actions: if .git exists, we stop.
# - ASCII-only script for Windows PowerShell 5.1 parsing stability.

$ErrorActionPreference = "Stop"

function Ensure-Dir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) {
    New-Item -ItemType Directory -Force -Path $p | Out-Null
  }
}

if (-not (Test-Path -LiteralPath $ProjectRoot)) {
  throw ("Project root not found: {0}" -f $ProjectRoot)
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw "git not found on PATH. Install Git for Windows and reopen the terminal."
}

Set-Location -LiteralPath $ProjectRoot

function Require-Success([string]$Step) {
  if ($LASTEXITCODE -ne 0) {
    throw ("Step failed: {0} (exit {1})" -f $Step, $LASTEXITCODE)
  }
}

$hasGitDir = Test-Path -LiteralPath (Join-Path $ProjectRoot ".git")
$hasCommits = $false
if ($hasGitDir) {
  # Use cmd.exe to avoid Windows PowerShell treating native stderr as terminating when EAP=Stop.
  cmd /c "git rev-parse --verify HEAD >nul 2>nul"
  if ($LASTEXITCODE -eq 0) { $hasCommits = $true }
}

# 1) Backup
$backupFile = $null
if (-not $SkipBackup) {
  Ensure-Dir $BackupRoot
  $backupFile = Join-Path $BackupRoot ("VaultGuard_Backup_{0}.zip" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
  Compress-Archive -Path (Join-Path $ProjectRoot "*") -DestinationPath $backupFile -CompressionLevel Optimal
}

# 2) Git init + first commit
if (-not $hasGitDir) {
  git init | Out-Null
  Require-Success "git init"
}

# Ensure repo-local identity exists (avoid --global)
$name = (git config --local user.name)
if (-not $name) { git config --local user.name "VaultGuard Local" | Out-Null }
$email = (git config --local user.email)
if (-not $email) { git config --local user.email "vaultguard@local" | Out-Null }

git add -A | Out-Null
Require-Success "git add -A"

if (-not $hasCommits) {
  git commit -m "Initial: VaultGuard (Phase 1 baseline)" -m ("Generated at: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss")) | Out-Null
  Require-Success "git commit (initial)"
}

# 3) Summary
$files = (git ls-files | Measure-Object).Count
$head = (git log --oneline -n 1 2>$null)

Write-Output "PHASE 1 DONE"
Write-Output ("Project: {0}" -f $ProjectRoot)
if ($backupFile) {
  $sizeMB = [math]::Round((Get-Item -LiteralPath $backupFile).Length / 1MB, 2)
  Write-Output ("Backup: {0} ({1} MB)" -f $backupFile, $sizeMB)
} else {
  Write-Output "Backup: SKIPPED"
}
Write-Output ("Repo files tracked: {0}" -f $files)
Write-Output ("Latest commit: {0}" -f $head)

if ($OpenAfter) {
  try { Start-Process explorer.exe -ArgumentList $ProjectRoot | Out-Null } catch { }
}

