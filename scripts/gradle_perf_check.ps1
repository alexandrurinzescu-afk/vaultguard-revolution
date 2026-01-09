param(
  [ValidateSet("full","incremental")]
  [string]$Mode = "full"
)

$ErrorActionPreference = "Stop"

function Write-Info([string]$Msg) { Write-Host $Msg -ForegroundColor Cyan }
function Write-Ok([string]$Msg) { Write-Host $Msg -ForegroundColor Green }
function Write-Warn([string]$Msg) { Write-Host $Msg -ForegroundColor Yellow }

$projectRoot = "C:\Users\pc\VaultGuardRevolution"
Push-Location $projectRoot
try {
  Write-Info "GRADLE PERFORMANCE CHECK (1.1.4)"
  Write-Info "1) gradlew --version"
  & .\gradlew.bat --version

  Write-Info "2) gradlew tasks"
  & .\gradlew.bat tasks > $null
  Write-Ok "tasks: OK"

  if ($Mode -eq "full") {
    Write-Info "3) clean assembleDebug (timed)"
    $t1 = Measure-Command { & .\gradlew.bat clean assembleDebug }
    Write-Ok ("clean assembleDebug: {0}s" -f ([math]::Round($t1.TotalSeconds, 2)))

    Write-Info "4) incremental assembleDebug (timed)"
    $t2 = Measure-Command { & .\gradlew.bat assembleDebug }
    Write-Ok ("assembleDebug (incremental): {0}s" -f ([math]::Round($t2.TotalSeconds, 2)))

    if ($t1.TotalSeconds -gt 60) {
      Write-Warn "Clean build > 60s. This can still be normal on first daemon warm-up or slower disks."
    }
    if ($t2.TotalSeconds -gt 10) {
      Write-Warn "Incremental build > 10s. This can be normal if inputs changed or daemon/cache cold."
    }
  } else {
    Write-Info "3) incremental assembleDebug (timed)"
    $t2 = Measure-Command { & .\gradlew.bat assembleDebug }
    Write-Ok ("assembleDebug (incremental): {0}s" -f ([math]::Round($t2.TotalSeconds, 2)))
  }
} finally {
  Pop-Location
}

