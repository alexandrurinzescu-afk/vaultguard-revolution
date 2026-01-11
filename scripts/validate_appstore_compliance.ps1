param(
  [Parameter(Mandatory = $false)]
  [string]$RoadmapPath = "",

  [Parameter(Mandatory = $false)]
  [switch]$Strict = $false
)

# VaultGuard App Store compliance validator (roadmap linter).
# PowerShell 5.1 friendly. ASCII-only output for stability.
#
# What it does:
# - Scans the roadmap text for high-risk phrases that commonly trigger App Store rejection.
# - Ensures mandatory compliance items exist in the roadmap (privacy, deletion, consent, iCloud constraints, monetization).
# - Prints a compact PASS/FAIL report and returns non-zero exit code on violations.

$ErrorActionPreference = "Stop"

function Write-Line([string]$msg) { Write-Host $msg }

if ([string]::IsNullOrWhiteSpace($RoadmapPath)) {
  $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
  $RoadmapPath = Join-Path $repoRoot "ROADMAP_FINAL.md"
}

if (-not (Test-Path -LiteralPath $RoadmapPath)) {
  Write-Line ("FAIL: Roadmap not found: {0}" -f $RoadmapPath)
  exit 2
}

$text = Get-Content -LiteralPath $RoadmapPath -Raw -ErrorAction Stop
$lower = $text.ToLowerInvariant()

function ContainsAny([string]$hay, [string[]]$needles) {
  foreach ($n in $needles) {
    if ($hay.Contains($n.ToLowerInvariant())) { return $true }
  }
  return $false
}

function MissingAll([string]$hay, [string[]]$needles) {
  return -not (ContainsAny $hay $needles)
}

# High-risk terms (common rejection triggers / enterprise-only assumptions)
$forbidden = @(
  "government verification",
  "elections",
  "surveillance",
  "covert",
  "silent iris",
  "background camera",
  "background mic",
  "keylogger",
  "mdm",
  "device-wide firewall",
  "enterprise program",
  "device management",
  "spy",
  "track users"
)

# Mandatory items requested in the mission.
$required = @(
  "privacy gateway",
  "data deletion flow",
  "huifan disclosure",
  "biometric consent",
  "no background processing",
  "revenuecat",
  "subscription"
)

# Special constraint: iCloud backup MUST exclude biometric templates.
$icloudMustHave = @(
  "icloud",
  "encrypted icloud backup"
)
$icloudMustAlsoSay = @(
  "not biometric templates",
  "excludes biometric templates",
  "documents only"
)

$issues = @()

foreach ($term in $forbidden) {
  if ($lower.Contains($term)) {
    $issues += ("FORBIDDEN_TERM: '{0}'" -f $term)
  }
}

foreach ($req in $required) {
  if ($lower.Contains($req) -eq $false) {
    $issues += ("MISSING_REQUIRED: '{0}'" -f $req)
  }
}

if (ContainsAny $lower $icloudMustHave) {
  if (MissingAll $lower $icloudMustAlsoSay) {
    $issues += "ICLOUD_RULE: iCloud backup mentioned but roadmap does not clearly state 'documents only' and 'NOT biometric templates'."
  }
} else {
  # Not strictly mandatory unless Strict is enabled
  if ($Strict) {
    $issues += "MISSING_REQUIRED: iCloud backup section not found (Strict mode)."
  }
}

# Huifan certification alignment: we can't verify certifications here, but we can enforce that risky
# statements are flagged as "Needs confirmation" somewhere in the roadmap.
$needsConfirmationMarkers = @("needs confirmation", "tbd")
if ($lower.Contains("huifan") -and (MissingAll $lower $needsConfirmationMarkers) -and $Strict) {
  $issues += "HUIFAN_RULE: Huifan is referenced but no 'Needs confirmation'/'TBD' marker found (Strict mode)."
}

Write-Line "APP STORE ROADMAP COMPLIANCE VALIDATION"
Write-Line ("Roadmap: {0}" -f $RoadmapPath)
Write-Line ("Strict:  {0}" -f ([bool]$Strict))
Write-Line "----------------------------------------"

if ($issues.Count -eq 0) {
  Write-Line "PASS: No violations detected."
  exit 0
}

Write-Line ("FAIL: {0} issue(s) detected:" -f $issues.Count)
foreach ($i in $issues) { Write-Line ("- {0}" -f $i) }
exit 1

