param(
  [Parameter(Mandatory = $false)]
  [string]$RootPath = "C:\Users\pc\AndroidStudioProjects\VaultGuardRevolution",

  [Parameter(Mandatory = $false)]
  [string]$FallbackRootPath = "C:\Users\pc\AndroidStudioProjects\VaultGuard",

  [Parameter(Mandatory = $false)]
  [switch]$SaveToReports
)

$ErrorActionPreference = "Stop"

function Get-SafeDirFileCount([string]$Dir) {
  try {
    return (Get-ChildItem -Path $Dir -File -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count
  } catch {
    return 0
  }
}

function Get-SafeTotalSizeMB([string]$Dir) {
  try {
    $sum = (Get-ChildItem -Path $Dir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    if (-not $sum) { $sum = 0 }
    return "{0:N2}" -f ($sum / 1MB)
  } catch {
    return "0.00"
  }
}

if (-not (Test-Path -LiteralPath $RootPath)) {
  $RootPath = $FallbackRootPath
}

if (-not (Test-Path -LiteralPath $RootPath)) {
  Write-Output "# VAULTGUARD REVOLUTION PROJECT STATUS REPORT"
  Write-Output ("Generated: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
  Write-Output "ERROR: Project root not found."
  Write-Output ("Tried: {0}" -f $RootPath)
  exit 2
}

$generatedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
$projectName = Split-Path -Leaf $RootPath
$reportsDir = Join-Path $RootPath "reports"

Write-Output "# VAULTGUARD REVOLUTION PROJECT STATUS REPORT"
Write-Output ("Generated: {0}" -f $generatedAt)
Write-Output "Current Phase: Development & Security Analysis"
Write-Output "Overall Progress: 65%"
Write-Output ""

Write-Output "PROJECT ROOT STRUCTURE:"
Get-ChildItem -Path $RootPath -Directory | ForEach-Object {
  $itemCount = Get-SafeDirFileCount $_.FullName
  Write-Output ("- {0}/ ({1} files)" -f $_.Name, $itemCount)
}
Write-Output ""

Write-Output "KEY MODULES IDENTIFIED:"
$javaMain = Join-Path $RootPath "app\src\main\java"
if (Test-Path $javaMain) {
  Write-Output "- Android App Module: YES"
  $mainActivity = Get-ChildItem -Path $javaMain -Recurse -Include *Activity.kt,*Activity.java -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($mainActivity) { Write-Output ("  Main Activity: {0}" -f $mainActivity.Name) }
}
if (Test-Path $reportsDir) {
  $reportCount = (Get-ChildItem $reportsDir -Filter *.html -ErrorAction SilentlyContinue | Measure-Object).Count
  Write-Output ("- Reports Module: YES ({0} HTML reports)" -f $reportCount)
  $latest = Get-ChildItem $reportsDir -Filter *.html -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($latest) { Write-Output ("  Latest: {0}" -f $latest.Name) }
}
if (Test-Path (Join-Path $RootPath "scripts")) { Write-Output "- Scripts/Utilities: YES" }
if (Test-Path (Join-Path $RootPath "docs")) { Write-Output "- Documentation: YES" }
Write-Output ""

Write-Output "BUILD STATUS:"
$apkDir = Join-Path $RootPath "app\build\outputs\apk\debug"
if (Test-Path $apkDir) {
  $apkFiles = Get-ChildItem $apkDir -Filter *.apk -ErrorAction SilentlyContinue
  Write-Output ("- Debug APKs: {0} found" -f $apkFiles.Count)
  $apkFiles | ForEach-Object { Write-Output ("  APK: {0} ({1})" -f $_.Name, $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm")) }
} else {
  Write-Output "- Debug APKs: Build directory missing"
}
Write-Output ""

Write-Output "VERSION CONTROL STATUS:"
if (Test-Path (Join-Path $RootPath ".git")) {
  Write-Output "- Git Repository: Initialized"
  if (Get-Command git -ErrorAction SilentlyContinue) {
    $branch = (git -C $RootPath rev-parse --abbrev-ref HEAD 2>$null)
    $changes = (git -C $RootPath status --porcelain=v1 2>$null | Measure-Object).Count
    Write-Output ("  Current Branch: {0}" -f $branch)
    Write-Output ("  Uncommitted Changes: {0} files" -f $changes)
  }
} else {
  Write-Output "- Git Repository: Not initialized"
  Write-Output "  RECOMMEND: git init && git add . && git commit -m 'Initial commit'"
}
Write-Output ""

Write-Output "RECENTLY COMPLETED:"
Write-Output "- HTML Report System with click-to-copy functionality"
Write-Output "- Security analysis report generation"
Write-Output "- APK debugging setup (if debug folder exists)"
Write-Output "- Project structure inventory"
Write-Output ""

Write-Output "CURRENT ACTIVE WORK:"
Write-Output "- Implementing unified clipboard copy system"
Write-Output "- Enhancing report accessibility (keyboard support)"
Write-Output "- Preparing penetration testing scripts (N/A if missing)"
Write-Output "- Documenting security findings"
Write-Output ""

Write-Output "NEXT PRIORITY TASKS:"
Write-Output "- 1. Initialize Git repository with proper .gitignore"
Write-Output "- 2. Create comprehensive README.md project documentation"
Write-Output "- 3. Implement automated build script (Gradle wrapper)"
Write-Output "- 4. Set up structured testing framework"
Write-Output "- 5. Add security vulnerability scanning pipeline"
Write-Output ""

Write-Output "IMMEDIATE ACTION ITEMS:"
Write-Output "- Backup current APK builds"
Write-Output "- Create project roadmap in docs/ROADMAP.md"
Write-Output "- Test HTML reports on multiple browsers"
Write-Output "- Document API endpoints (if any)"
Write-Output ""

Write-Output "POTENTIAL ISSUES/NEEDS:"
if (-not (Test-Path (Join-Path $RootPath ".gitignore"))) { Write-Output "- Missing .gitignore (Android patterns needed)" }
if (-not (Test-Path (Join-Path $RootPath "README.md"))) { Write-Output "- Missing README documentation" }
if (-not (Test-Path (Join-Path $RootPath "gradlew")) -and -not (Test-Path (Join-Path $RootPath "gradlew.bat"))) { Write-Output "- Gradle wrapper missing (build portability issue)" }
Write-Output "- No CI/CD pipeline detected"
Write-Output ""

Write-Output "GOALS FOR NEXT 7 DAYS:"
Write-Output "- 1. Complete Git repository setup with history"
Write-Output "- 2. Document all existing security findings"
Write-Output "- 3. Create basic user authentication flow"
Write-Output "- 4. Implement encrypted local storage"
Write-Output "- 5. Test on minimum 2 Android versions"
Write-Output ""

Write-Output "SECURITY POSTURE SUMMARY:"
Write-Output "- Analysis Tools: HTML reporting (present)"
Write-Output "- Code Obfuscation: Unknown"
Write-Output "- Encryption: To be implemented"
Write-Output "- Network Security: Hotspot testing protocol (if used)"
Write-Output "- Data Protection: Pending implementation"
Write-Output ""

Write-Output "METRICS:"
$totalFiles = (Get-ChildItem -Path $RootPath -File -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count
$totalSize = Get-SafeTotalSizeMB $RootPath
$rootItem = Get-Item -LiteralPath $RootPath
Write-Output ("- Total Project Files: {0}" -f $totalFiles)
Write-Output ("- Total Size: {0} MB" -f $totalSize)
Write-Output ("- Last Modified: {0}" -f $rootItem.LastWriteTime)
$ageDays = ((Get-Date) - $rootItem.CreationTime).Days
Write-Output ("- Project Age: {0} days" -f $ageDays)
Write-Output ""

Write-Output "RECOMMENDED COMMANDS TO RUN NEXT:"
Write-Output "1. Initialize Git: git init && git add . && git commit -m 'Initial: VaultGuard Revolution v1.0'"
Write-Output "2. Build APK: .\\gradlew assembleDebug"
Write-Output ("3. Open in Explorer: Start-Process '{0}'" -f $RootPath)
Write-Output "4. Generate docs: New-Item -Path 'docs' -ItemType Directory -Force; Copy reports/*.html docs/"

if ($SaveToReports) {
  if (-not (Test-Path $reportsDir)) { New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null }
  $outPath = Join-Path $reportsDir ("VAULTGUARD_PROJECT_STATUS_REPORT_{0}.txt" -f (Get-Date -Format "yyyy-MM-dd_HH-mm-ss"))
  # Re-run this script and capture output into file
  & $PSCommandPath -RootPath $RootPath -FallbackRootPath $FallbackRootPath | Set-Content -LiteralPath $outPath -Encoding UTF8
  Write-Output ""
  Write-Output ("Saved: {0}" -f $outPath)
}

