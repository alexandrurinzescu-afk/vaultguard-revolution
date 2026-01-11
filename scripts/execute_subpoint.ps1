# VAULTGUARD REVOLUTION - SUBPOINT EXECUTION TEMPLATE
param(
  [Parameter(Mandatory = $true)]
  # Allow optional suffix like 2.1.1-CLEANUP, but protocol checks use numeric base (2.1.1).
  [ValidatePattern("^\d+\.\d+\.\d+(-[A-Za-z0-9_]+)?$")]
  [string]$Subpoint,

  [Parameter(Mandatory = $true)]
  [string]$Description
)

$ErrorActionPreference = "Stop"

function Write-Info([string]$Msg) { Write-Host $Msg -ForegroundColor Cyan }
function Write-Ok([string]$Msg) { Write-Host $Msg -ForegroundColor Green }
function Write-Err([string]$Msg) { Write-Host $Msg -ForegroundColor Red }

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$protocol = Join-Path $PSScriptRoot "enforce_protocol.ps1"

$numericSubpoint = ($Subpoint -split "-", 2)[0]

Write-Host ("EXECUTING SUBPOINT: {0}" -f $Subpoint) -ForegroundColor Magenta
Write-Host ("Description: {0}" -f $Description) -ForegroundColor White
Write-Host "==========================================" -ForegroundColor DarkMagenta

# 1) Protocol pre-check
Write-Info ""
Write-Info "STEP 1: Protocol Pre-Check"
if (-not (Test-Path -LiteralPath $protocol)) {
  Write-Err ("Protocol script missing: {0}" -f $protocol)
  exit 1
}

try {
  # Reset LASTEXITCODE so we don't inherit a previous native command exit code.
  $global:LASTEXITCODE = 0

  # Pass full subpoint to protocol so it can apply suffix rules (e.g. -CLEANUP override).
  & $protocol -CurrentSubpoint $Subpoint -Operation "pre-check"
} catch {
  Write-Err "SUBPOINT EXECUTION BLOCKED BY PROTOCOL"
  exit 1
}

# If protocol script used exit codes (common for pre-check), respect them.
if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
  Write-Err ("SUBPOINT EXECUTION BLOCKED BY PROTOCOL (exit {0})" -f $LASTEXITCODE)
  exit $LASTEXITCODE
}

# 2) Implementation guidance
Write-Info ""
Write-Info "STEP 2: Implementation Phase"
Write-Host ("  Implement ONLY: {0} (protocol base: {1})" -f $Subpoint, $numericSubpoint) -ForegroundColor White
Write-Host ("  Temp dir: {0}" -f (Join-Path $projectRoot ("_temp_debug_{0}" -f $numericSubpoint))) -ForegroundColor Gray
Write-Host "  Debug artifacts allowed ONLY in that temp dir. They will be deleted after backup." -ForegroundColor Yellow

# 3) Post-implementation
Write-Info ""
Write-Info "STEP 3: After Implementation Complete"
Write-Host "  1) Test until 100% functional" -ForegroundColor White
Write-Host ("  2) Run backup: .\\scripts\\backup_after_subpoint.ps1 -Chapter ""{0}"" -Subpoint ""{1}"" -Description ""{2}""" -f ($numericSubpoint -replace "\.\d+$",""), $numericSubpoint, $Description) -ForegroundColor Green
Write-Host "  3) Protocol auto-cleans temp files during backup" -ForegroundColor Gray
Write-Host "  4) Only then proceed to next subpoint" -ForegroundColor Yellow

Write-Ok ""
Write-Ok "READY FOR IMPLEMENTATION."

