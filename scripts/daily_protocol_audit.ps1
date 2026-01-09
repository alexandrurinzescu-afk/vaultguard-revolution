# Daily audit to ensure protocol compliance (PowerShell 5.1 friendly)
$ErrorActionPreference = "Stop"

function Write-Info([string]$Msg) { Write-Host $Msg -ForegroundColor Cyan }
function Write-Ok([string]$Msg) { Write-Host $Msg -ForegroundColor Green }
function Write-Warn([string]$Msg) { Write-Host $Msg -ForegroundColor Yellow }
function Write-Err([string]$Msg) { Write-Host $Msg -ForegroundColor Red }

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$roadmapFile = Join-Path $projectRoot "VAULTGUARD_REVOLUTION_ROADMAP.md"

function Test-IsExcludedPath([string]$FullPath) {
  $p = $FullPath.ToLowerInvariant()
  return (
    $p -like "*\vaultguardrevolution\.git\*" -or
    $p -like "*\vaultguardrevolution\.gradle\*" -or
    $p -like "*\vaultguardrevolution\.idea\*" -or
    $p -like "*\vaultguardrevolution\app\build\*" -or
    $p -like "*\vaultguardrevolution\build\*" -or
    $p -like "*\vaultguardrevolution\backups\*" -or
    $p -like "*\vaultguardrevolution\reports\*" -or
    $p -like "*\vaultguardrevolution\.cxx\*" -or
    $p -like "*\vaultguardrevolution\.kotlin\*"
  )
}

$auditDate = Get-Date -Format "yyyy-MM-dd"
$auditDir = "C:\VAULTGUARD_UNIVERSE\AUDITS"
$auditLog = Join-Path $auditDir ("protocol_audit_{0}.txt" -f $auditDate)

New-Item -ItemType Directory -Force -Path $auditDir | Out-Null

Write-Info ("DAILY PROTOCOL AUDIT - {0}" -f $auditDate)
Write-Info ("Project root: {0}" -f $projectRoot)

# 1) Orphaned temp artifacts (only protocol-managed patterns)
$orphanedDirs = Get-ChildItem -LiteralPath $projectRoot -Directory -Filter "_temp_debug_*" -ErrorAction SilentlyContinue
$orphanedFiles = Get-ChildItem -LiteralPath $projectRoot -File -Recurse -ErrorAction SilentlyContinue |
  Where-Object {
    (-not (Test-IsExcludedPath $_.FullName)) -and (
      $_.Name -match "(?i)(_temp\\.)" -or
      $_.Extension -match "^(?i)\\.tmp$|\\.debug$"
    )
  }

if (($orphanedDirs.Count -gt 0) -or ($orphanedFiles.Count -gt 0)) {
  Write-Warn ("FOUND ORPHANED TEMP ARTIFACTS: dirs={0}, files={1}" -f $orphanedDirs.Count, $orphanedFiles.Count)
  foreach ($d in $orphanedDirs) { try { Remove-Item -LiteralPath $d.FullName -Recurse -Force } catch { } }
  foreach ($f in $orphanedFiles) { try { Remove-Item -LiteralPath $f.FullName -Force } catch { } }
  Write-Ok "Orphaned temp artifacts cleaned."
} else {
  Write-Ok "No orphaned temp artifacts found."
}

# 2) Roadmap sequential consistency (no completed after first incomplete)
if (-not (Test-Path -LiteralPath $roadmapFile)) {
  Write-Err ("Roadmap missing: {0}" -f $roadmapFile)
  exit 1
}
$roadmap = Get-Content -LiteralPath $roadmapFile -Raw
$matches = [regex]::Matches($roadmap, "(?m)^- \[([ xX])\]\s+(\d+\.\d+\.\d+)\b")

$seenIncomplete = $false
$violation = $false
$violationFirst = $null

foreach ($m in $matches) {
  $mark = $m.Groups[1].Value
  $id = $m.Groups[2].Value
  if ($mark -match "^[ ]$") {
    $seenIncomplete = $true
    continue
  }
  if (($mark -match "^[xX]$") -and $seenIncomplete) {
    $violation = $true
    $violationFirst = $id
    break
  }
}

if ($violation) {
  Write-Warn ("POTENTIAL PROTOCOL VIOLATION: Completed subpoint found after incomplete sequence starts (first detected: {0})." -f $violationFirst)
} else {
  Write-Ok "Roadmap order looks sequential (no obvious skip patterns)."
}

# 3) Write audit log
$lines = @()
$lines += ("DATE: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
$lines += ("PROJECT_ROOT: {0}" -f $projectRoot)
$lines += ("ORPHANED_DIRS: {0}" -f $orphanedDirs.Count)
$lines += ("ORPHANED_FILES: {0}" -f $orphanedFiles.Count)
$lines += ("ROADMAP_VIOLATION: {0}" -f $violation)
if ($violationFirst) { $lines += ("VIOLATION_FIRST: {0}" -f $violationFirst) }
$lines += ""

Add-Content -LiteralPath $auditLog -Value ($lines -join "`r`n")
Write-Ok ("DAILY AUDIT COMPLETE. Log: {0}" -f $auditLog)

