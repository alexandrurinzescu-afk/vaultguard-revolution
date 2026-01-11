param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = "",

  [Parameter(Mandatory = $false)]
  [int]$MinFreeRamMB = 2048,

  [Parameter(Mandatory = $false)]
  [int]$MinPagefileMB = 8192
)

# Pre-flight check for stable unattended work.
# PowerShell 5.1 friendly; best-effort checks (some WMI calls can fail on constrained systems).

$ErrorActionPreference = "Stop"

function Write-Ok([string]$Msg) { Write-Host $Msg -ForegroundColor Green }
function Write-Warn([string]$Msg) { Write-Host $Msg -ForegroundColor Yellow }
function Write-Err([string]$Msg) { Write-Host $Msg -ForegroundColor Red }

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

if (-not (Test-Path -LiteralPath $ProjectRoot)) {
  Write-Err ("FAIL: Project root not found: {0}" -f $ProjectRoot)
  exit 2
}

$gradleProps = Join-Path $ProjectRoot "gradle.properties"
if (-not (Test-Path -LiteralPath $gradleProps)) {
  Write-Err ("FAIL: gradle.properties missing: {0}" -f $gradleProps)
  exit 2
}

$gp = Get-Content -LiteralPath $gradleProps -Raw -ErrorAction Stop

$requiredLines = @(
  "org.gradle.daemon=false",
  "org.gradle.workers.max=2",
  "org.gradle.jvmargs=-Xmx1024m",
  "kotlin.daemon.jvmargs=-Xmx512m"
)

$errors = @()
foreach ($r in $requiredLines) {
  if ($gp -notmatch [regex]::Escape($r)) { $errors += ("Missing/incorrect gradle.properties setting: {0}" -f $r) }
}

try {
  $os = Get-CimInstance Win32_OperatingSystem
  $freeRamMB = [int]([math]::Round($os.FreePhysicalMemory / 1024.0))
  if ($freeRamMB -lt $MinFreeRamMB) {
    $errors += ("Low RAM: free={0}MB (min={1}MB)" -f $freeRamMB, $MinFreeRamMB)
  } else {
    Write-Ok ("RAM OK: free={0}MB (min={1}MB)" -f $freeRamMB, $MinFreeRamMB)
  }
} catch {
  Write-Warn ("WARN: Could not read RAM info: {0}" -f $_.Exception.Message)
}

try {
  # Best-effort: pagefile usage can be missing depending on policy.
  $pf = Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($pf -and $pf.AllocatedBaseSize -ne $null) {
    $allocated = [int]$pf.AllocatedBaseSize
    if ($allocated -lt $MinPagefileMB) {
      $errors += ("Paging file too small: allocated={0}MB (min={1}MB)" -f $allocated, $MinPagefileMB)
    } else {
      Write-Ok ("Paging OK: allocated={0}MB (min={1}MB)" -f $allocated, $MinPagefileMB)
    }
  } else {
    Write-Warn "WARN: Could not read paging allocation (Win32_PageFileUsage unavailable)."
    Write-Warn "      Ensure Virtual Memory is System managed size or >= 8–16GB."
  }
} catch {
  Write-Warn ("WARN: Could not read paging info: {0}" -f $_.Exception.Message)
}

if ($errors.Count -gt 0) {
  Write-Err "FAIL: Pre-flight check failed:"
  foreach ($e in $errors) { Write-Host ("- {0}" -f $e) -ForegroundColor Red }
  exit 1
}

Write-Ok "PASS: Pre-flight check OK."
exit 0

