param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = "C:\Users\pc\AndroidStudioProjects\VaultGuard",

  [Parameter(Mandatory = $false)]
  [switch]$ForceUpdate
)

# Installs VaultGuard PowerShell Auto-Report into the current user's $PROFILE:
# - Creates $PROFILE file if missing
# - Appends OR replaces a marked block (idempotent)
# - Enables emoji labels via: $global:VG_AUTO_REPORT_EMOJI = $true
# Windows PowerShell 5.1 friendly (script contains no literal emoji; emoji are generated at runtime).

$ErrorActionPreference = "Stop"

function Ensure-Dir([string]$p) {
  $dir = Split-Path -Parent $p
  if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
}

function Replace-MarkedBlock {
  param(
    [Parameter(Mandatory = $true)][string]$Text,
    [Parameter(Mandatory = $true)][string]$MarkerStart,
    [Parameter(Mandatory = $true)][string]$MarkerEnd,
    [Parameter(Mandatory = $true)][string]$NewBlock
  )

  $startIdx = $Text.IndexOf($MarkerStart)
  if ($startIdx -lt 0) { return $null }

  $endIdx = $Text.IndexOf($MarkerEnd, $startIdx)
  if ($endIdx -lt 0) { return $null }

  $endIdx = $endIdx + $MarkerEnd.Length
  $before = $Text.Substring(0, $startIdx)
  $after = $Text.Substring($endIdx)
  return ($before + $NewBlock + $after)
}

if (-not (Test-Path -LiteralPath $ProjectRoot)) {
  throw ("Project root not found: {0}" -f $ProjectRoot)
}

$scriptPath = Join-Path $ProjectRoot "scripts\powershell_auto_report.ps1"
if (-not (Test-Path -LiteralPath $scriptPath)) {
  throw ("Auto-report script not found: {0}" -f $scriptPath)
}

$profilePath = $PROFILE
Ensure-Dir $profilePath

if (-not (Test-Path -LiteralPath $profilePath)) {
  New-Item -ItemType File -Force -Path $profilePath | Out-Null
}

$markerStart = "# >>> VaultGuard Auto-Report (installed)"
$markerEnd = "# <<< VaultGuard Auto-Report (installed)"

# IMPORTANT: build block lines explicitly so $global:* does not expand during install.
$blockLines = @(
  $markerStart,
  '$global:VG_AUTO_REPORT_EMOJI = $true',
  ("if (Test-Path -LiteralPath '{0}') {{ . '{0}' }}" -f $scriptPath),
  $markerEnd,
  ""
)
$block = ($blockLines -join "`r`n")

$raw = Get-Content -LiteralPath $profilePath -Raw -ErrorAction SilentlyContinue
if (-not $raw) { $raw = "" }

$hasBlock = $raw.Contains($markerStart)

if ($hasBlock -and (-not $ForceUpdate)) {
  Write-Output ("Already installed in profile: {0}" -f $profilePath)
  Write-Output ("Script: {0}" -f $scriptPath)
  Write-Output "Tip: re-run with -ForceUpdate to refresh the installed block."
  exit 0
}

if ($hasBlock -and $ForceUpdate) {
  $updated = Replace-MarkedBlock -Text $raw -MarkerStart $markerStart -MarkerEnd $markerEnd -NewBlock $block
  if (-not $updated) { $updated = ($raw + "`r`n" + $block) }

  Set-Content -LiteralPath $profilePath -Value $updated -Encoding UTF8
  Write-Output "UPDATED: VaultGuard Auto-Report block in profile"
  Write-Output ("Profile: {0}" -f $profilePath)
  Write-Output ("Script:  {0}" -f $scriptPath)
  exit 0
}

Add-Content -LiteralPath $profilePath -Value ("`r`n" + $block) -Encoding UTF8

Write-Output "INSTALLED: VaultGuard Auto-Report"
Write-Output ("Profile: {0}" -f $profilePath)
Write-Output ("Script:  {0}" -f $scriptPath)
Write-Output ""
Write-Output "Open a new PowerShell terminal (or run: . $PROFILE) then use:"
Write-Output "  ir ""Get-Date"""
Write-Output "  ir ""echo 'Hello Auto-Report'"""

