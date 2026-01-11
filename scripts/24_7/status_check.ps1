param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
}

$trackDir = Join-Path $ProjectRoot "reports\\24_7_tracking"
$csv = Join-Path $trackDir "progress.csv"
$admin = Join-Path $trackDir "admin_blockers.md"
$control = Join-Path $trackDir "control_signal.txt"

Write-Host "24/7 STATUS CHECK" -ForegroundColor Cyan
Write-Host ("Time:   {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
Write-Host ("Track:  {0}" -f $trackDir)
Write-Host ("Signal: {0}" -f (Get-Content -LiteralPath $control -Raw -ErrorAction SilentlyContinue).Trim())
Write-Host ""

if (Test-Path -LiteralPath $csv) {
  Write-Host "Last 10 progress rows:" -ForegroundColor White
  Get-Content -LiteralPath $csv -Tail 10 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ }
} else {
  Write-Host "progress.csv not found yet." -ForegroundColor Yellow
}

Write-Host ""
if (Test-Path -LiteralPath $admin) {
  $count = (Get-Content -LiteralPath $admin -ErrorAction SilentlyContinue | Select-String -Pattern "^## " | Measure-Object).Count
  Write-Host ("Admin blockers entries: {0}" -f $count) -ForegroundColor White
} else {
  Write-Host "admin_blockers.md not found yet." -ForegroundColor Yellow
}

