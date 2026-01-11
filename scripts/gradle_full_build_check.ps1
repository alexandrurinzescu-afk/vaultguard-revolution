$ErrorActionPreference = "Stop"

function Write-Info([string]$Msg) { Write-Host $Msg -ForegroundColor Cyan }
function Write-Ok([string]$Msg) { Write-Host $Msg -ForegroundColor Green }

$projectRoot = "C:\Users\pc\VaultGuardRevolution"
Push-Location $projectRoot
try {
  Write-Info "FULL BUILD CHECK (1.1.5): gradlew clean build"
  $t = Measure-Command { & .\gradlew.bat clean build --no-daemon }
  if ($LASTEXITCODE -ne 0) {
    throw ("Build failed (exit code {0})." -f $LASTEXITCODE)
  }
  Write-Ok ("BUILD OK. Duration: {0}s" -f ([math]::Round($t.TotalSeconds, 2)))
} finally {
  Pop-Location
}

