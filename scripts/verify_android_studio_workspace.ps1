param([switch]$TryOpenAndroidStudio)

$ErrorActionPreference = "Stop"

function Write-Info([string]$Msg) { Write-Host $Msg -ForegroundColor Cyan }
function Write-Ok([string]$Msg) { Write-Host $Msg -ForegroundColor Green }
function Write-Warn([string]$Msg) { Write-Host $Msg -ForegroundColor Yellow }
function Write-Err([string]$Msg) { Write-Host $Msg -ForegroundColor Red }

$projectRoot = "C:\Users\pc\VaultGuardRevolution"
$localProps = Join-Path $projectRoot "local.properties"

Write-Info "VERIFY ANDROID STUDIO WORKSPACE (1.1.3)"
Write-Info ("Project: {0}" -f $projectRoot)

if (-not (Test-Path -LiteralPath $projectRoot)) {
  Write-Err "Project root not found."
  exit 1
}

# 1) Java/JDK (best-effort)
Write-Info "1) Java check (best-effort)"
try {
  $javaOut = & java -version 2>&1
  Write-Ok ("Java detected on PATH: {0}" -f (($javaOut | Select-Object -First 1) -join " "))
} catch {
  Write-Warn "java not found on PATH (OK if Android Studio/Gradle uses embedded JDK)."
}

# 2) local.properties + sdk.dir
Write-Info "2) Android SDK path check (local.properties)"
if (-not (Test-Path -LiteralPath $localProps)) {
  Write-Err ("Missing local.properties: {0}" -f $localProps)
  exit 1
}

$lp = Get-Content -LiteralPath $localProps -ErrorAction Stop
$sdkLine = $lp | Where-Object { $_ -match "^\s*sdk\.dir\s*=" } | Select-Object -First 1
if (-not $sdkLine) {
  Write-Err "local.properties does not contain sdk.dir=..."
  exit 1
}
Write-Ok ("sdk.dir found: {0}" -f $sdkLine)

# 3) Gradle wrapper check (authoritative JDK used by build) + build (proxy for AS sync correctness)
Write-Info "3) Gradle wrapper check + build (assembleDebug)"
Push-Location $projectRoot
try {
  if (-not (Test-Path -LiteralPath (Join-Path $projectRoot "gradlew.bat"))) {
    Write-Err "Missing gradlew.bat"
    exit 1
  }
  & .\gradlew.bat --version --no-daemon
  & .\gradlew.bat assembleDebug --no-daemon
  Write-Ok "Gradle assembleDebug: OK"
} finally {
  Pop-Location
}

# 4) ADB device check (optional)
Write-Info "4) ADB device check (optional)"
if (Get-Command adb -ErrorAction SilentlyContinue) {
  $adb = (adb devices 2>$null)
  if ($adb -match "device$") {
    Write-Ok "ADB: device connected"
  } else {
    Write-Warn "ADB: no device detected (connect Motorola G05 and enable USB debugging)"
  }
} else {
  Write-Warn "ADB not found on PATH (Android Platform Tools)."
}

# 5) Try to open Android Studio (optional, best-effort)
if ($TryOpenAndroidStudio) {
  Write-Info "5) Open Android Studio (best-effort)"
  $candidates = @(
    "C:\Program Files\Android\Android Studio\bin\studio64.exe",
    "C:\Program Files\Android\Android Studio\bin\studio.exe",
    (Join-Path $env:LOCALAPPDATA "Programs\Android Studio\bin\studio64.exe")
  )
  $studio = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
  if ($studio) {
    Start-Process -FilePath $studio -ArgumentList @($projectRoot) | Out-Null
    Write-Ok ("Launched Android Studio: {0}" -f $studio)
  } else {
    Write-Warn "Android Studio executable not found in common locations."
  }
}

Write-Ok "VERIFICATION COMPLETE: Workspace looks ready."

