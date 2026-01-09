param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = "C:\Users\pc\AndroidStudioProjects\VaultGuard",

  [Parameter(Mandatory = $false)]
  [switch]$OpenReports
)

# VaultGuard - Final Status Report & Roadmap Generator
# - Script file is ASCII-only to avoid Windows PowerShell 5.1 parsing issues.
# - Output files are UTF-8 (with BOM) for safe display of icons/emojis in reports.

$ErrorActionPreference = "Stop"

function Ensure-Dir([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
  }
}

function Get-SafeFileCount([string]$Dir) {
  try { return (Get-ChildItem -Path $Dir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count } catch { return 0 }
}

function Get-SafeTotalSizeMB([string]$Dir) {
  try {
    $sum = (Get-ChildItem -Path $Dir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    if (-not $sum) { $sum = 0 }
    return ("{0:N2}" -f ($sum / 1MB))
  } catch {
    return "0.00"
  }
}

function Try-GetGitSummary([string]$Dir) {
  $gitDir = Join-Path $Dir ".git"
  if (-not (Test-Path -LiteralPath $gitDir)) {
    return [PSCustomObject]@{ initialized = $false; branch = $null; commits = $null; uncommitted = $null; error = $null }
  }
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    return [PSCustomObject]@{ initialized = $true; branch = $null; commits = $null; uncommitted = $null; error = "git command not found" }
  }
  try {
    $branch = (git -C $Dir rev-parse --abbrev-ref HEAD 2>$null)
    $commits = (git -C $Dir log --oneline 2>$null | Measure-Object).Count
    $uncommitted = (git -C $Dir status --porcelain=v1 2>$null | Measure-Object).Count
    return [PSCustomObject]@{ initialized = $true; branch = $branch; commits = $commits; uncommitted = $uncommitted; error = $null }
  } catch {
    return [PSCustomObject]@{ initialized = $true; branch = $null; commits = $null; uncommitted = $null; error = $_.Exception.Message }
  }
}

function Find-AndroidSdkInfo([string]$Root) {
  $result = [ordered]@{ minSdk = $null; targetSdk = $null; compileSdk = $null; source = $null }
  $candidates = @(
    (Join-Path $Root "app\build.gradle.kts"),
    (Join-Path $Root "app\build.gradle"),
    (Join-Path $Root "build.gradle.kts"),
    (Join-Path $Root "build.gradle")
  ) | Where-Object { Test-Path -LiteralPath $_ }

  foreach ($f in $candidates) {
    try {
      $txt = Get-Content -LiteralPath $f -Raw -ErrorAction Stop
      if (-not $result.compileSdk) {
        $m = [regex]::Match($txt, "compileSdk\s*=?\s*(\d+)", "IgnoreCase")
        if ($m.Success) { $result.compileSdk = $m.Groups[1].Value }
      }
      if (-not $result.minSdk) {
        $m = [regex]::Match($txt, "minSdk(?:Version)?\s*=?\s*(\d+)", "IgnoreCase")
        if ($m.Success) { $result.minSdk = $m.Groups[1].Value }
      }
      if (-not $result.targetSdk) {
        $m = [regex]::Match($txt, "targetSdk(?:Version)?\s*=?\s*(\d+)", "IgnoreCase")
        if ($m.Success) { $result.targetSdk = $m.Groups[1].Value }
      }
      if ($result.minSdk -or $result.targetSdk -or $result.compileSdk) {
        $result.source = $f
        break
      }
    } catch { }
  }

  if (-not $result.minSdk) { $result.minSdk = "[TO BE VERIFIED]" }
  if (-not $result.targetSdk) { $result.targetSdk = "[TO BE VERIFIED]" }
  if (-not $result.compileSdk) { $result.compileSdk = "[TO BE VERIFIED]" }
  if (-not $result.source) { $result.source = "[NOT DETECTED]" }
  return [PSCustomObject]$result
}

function Compute-Progress([string]$Root, $git, $sdk, $apkCount) {
  # Heuristic scoring based on what exists.
  $scores = [ordered]@{
    infrastructure = 0
    reporting      = 0
    security       = 0
    documentation  = 0
    testing        = 0
    deployment     = 0
  }

  # Infrastructure
  $hasGradleWrapper = (Test-Path -LiteralPath (Join-Path $Root "gradle\wrapper\gradle-wrapper.properties"))
  $hasSettings = (Test-Path -LiteralPath (Join-Path $Root "settings.gradle.kts")) -or (Test-Path -LiteralPath (Join-Path $Root "settings.gradle"))
  $scores.infrastructure = 40 + ($(if ($hasSettings) { 20 } else { 0 })) + ($(if ($hasGradleWrapper) { 20 } else { 0 })) + ($(if ($apkCount -gt 0) { 20 } else { 0 }))
  if ($scores.infrastructure -gt 100) { $scores.infrastructure = 100 }

  # Reporting
  $reportsDir = Join-Path $Root "reports"
  $htmlCount = 0
  if (Test-Path -LiteralPath $reportsDir) { $htmlCount = (Get-ChildItem -Path $reportsDir -Filter *.html -ErrorAction SilentlyContinue | Measure-Object).Count }
  $scores.reporting = if ($htmlCount -ge 1) { 90 } else { 20 }

  # Security (very conservative: only detect if KeystoreManager exists)
  $keystore = Get-ChildItem -Path (Join-Path $Root "app\src\main\java") -Recurse -Filter *Keystore* -ErrorAction SilentlyContinue | Select-Object -First 1
  $scores.security = if ($keystore) { 35 } else { 15 }

  # Documentation
  $scores.documentation = 0
  if (Test-Path -LiteralPath (Join-Path $Root "README.md")) { $scores.documentation += 40 }
  if (Test-Path -LiteralPath (Join-Path $Root "docs")) { $scores.documentation += 20 }
  if ($scores.documentation -gt 100) { $scores.documentation = 100 }

  # Testing
  $hasAndroidTests = Test-Path -LiteralPath (Join-Path $Root "app\src\androidTest")
  $hasUnitTests = Test-Path -LiteralPath (Join-Path $Root "app\src\test")
  $scores.testing = ($(if ($hasUnitTests) { 35 } else { 10 })) + ($(if ($hasAndroidTests) { 35 } else { 10 }))
  if ($scores.testing -gt 100) { $scores.testing = 100 }

  # Deployment (Git + CI hints)
  $hasCI = (Test-Path -LiteralPath (Join-Path $Root ".github\workflows")) -or (Test-Path -LiteralPath (Join-Path $Root ".gitlab-ci.yml"))
  $scores.deployment = 10 + ($(if ($git.initialized) { 20 } else { 0 })) + ($(if ($hasCI) { 30 } else { 0 })) + ($(if ($apkCount -gt 0) { 20 } else { 0 }))
  if ($scores.deployment -gt 100) { $scores.deployment = 100 }

  $overall = [math]::Round((($scores.Values | Measure-Object -Average).Average))
  return [PSCustomObject]@{ overall = $overall; details = $scores }
}

if (-not (Test-Path -LiteralPath $ProjectRoot)) {
  throw ("Project root not found: {0}" -f $ProjectRoot)
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$reportsDir = Join-Path $ProjectRoot "reports"
Ensure-Dir $reportsDir

$sdk = Find-AndroidSdkInfo $ProjectRoot
$git = Try-GetGitSummary $ProjectRoot

$srcRoot = Join-Path $ProjectRoot "app\src"
$javaFiles = @(Get-ChildItem -Path $srcRoot -Recurse -Filter *.java -ErrorAction SilentlyContinue)
$ktFiles = @(Get-ChildItem -Path $srcRoot -Recurse -Filter *.kt -ErrorAction SilentlyContinue)
$xmlFiles = @(Get-ChildItem -Path $srcRoot -Recurse -Filter *.xml -ErrorAction SilentlyContinue)

$apkDir = Join-Path $ProjectRoot "app\build\outputs\apk\debug"
$apkFiles = @()
if (Test-Path -LiteralPath $apkDir) {
  $apkFiles = @(Get-ChildItem -Path $apkDir -Filter *.apk -ErrorAction SilentlyContinue)
}
$latestApk = $null
if ($apkFiles.Count -gt 0) { $latestApk = ($apkFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1) }

$progress = Compute-Progress -Root $ProjectRoot -git $git -sdk $sdk -apkCount $apkFiles.Count

$totalFiles = Get-SafeFileCount $ProjectRoot
$totalSizeMB = Get-SafeTotalSizeMB $ProjectRoot
$rootItem = Get-Item -LiteralPath $ProjectRoot
$ageDays = ((Get-Date) - $rootItem.CreationTime).Days
$lastModified = $rootItem.LastWriteTime.ToString("yyyy-MM-dd HH:mm")

$latestHtml = $null
try {
  $latestHtml = Get-ChildItem -Path $reportsDir -Filter *.html -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
} catch { }

$txtPath = Join-Path $reportsDir ("VAULTGUARD_FINAL_STATUS_ROADMAP_{0}.txt" -f $timestamp)
$htmlPath = $txtPath -replace "\.txt$", ".html"

$lines = @()
$lines += "# VAULTGUARD - FINAL STATUS REPORT & ROADMAP"
$lines += ("Generated: {0}" -f $generatedAt)
$lines += ("Project Root: {0}" -f $ProjectRoot)
$lines += ("Current Phase: ACTIVE DEVELOPMENT")
$lines += ("Overall Progress: {0}%" -f $progress.overall)
$lines += ("Health Status: OPERATIONAL")
$lines += ("Security Posture: IMPROVEMENT NEEDED")
$lines += ""
$lines += "## PROJECT STRUCTURE ANALYSIS"
$lines += ("- Android module: app/")
$lines += ("  - Min SDK: {0}" -f $sdk.minSdk)
$lines += ("  - Target SDK: {0}" -f $sdk.targetSdk)
$lines += ("  - Compile SDK: {0}" -f $sdk.compileSdk)
$lines += ("  - SDK source: {0}" -f $sdk.source)
$lines += ("  - Source files: {0} Java, {1} Kotlin, {2} XML" -f $javaFiles.Count, $ktFiles.Count, $xmlFiles.Count)
$lines += ("  - Debug APKs: {0}" -f $apkFiles.Count)
if ($latestApk) { $lines += ("  - Latest APK: {0} ({1})" -f $latestApk.Name, $latestApk.LastWriteTime.ToString("yyyy-MM-dd HH:mm")) }
$lines += ("- Reports: reports/ ({0} HTML)" -f ((Get-ChildItem -Path $reportsDir -Filter *.html -ErrorAction SilentlyContinue | Measure-Object).Count))
if ($latestHtml) { $lines += ("  - Latest HTML: {0}" -f $latestHtml.Name) }
$lines += ""
$lines += "## VERSION CONTROL STATUS"
if (-not $git.initialized) {
  $lines += "Git: NOT INITIALIZED (CRITICAL)"
  $lines += "Recommended:"
  $lines += "  git init"
  $lines += "  git add ."
  $lines += '  git commit -m "Initial: VaultGuard v1.0"'
} elseif ($git.error) {
  $lines += "Git: DETECTED but error while reading status"
  $lines += ("Error: {0}" -f $git.error)
} else {
  $lines += "Git: INITIALIZED"
  $lines += ("Branch: {0}" -f $git.branch)
  $lines += ("Commits: {0}" -f $git.commits)
  $lines += ("Uncommitted changes: {0} files" -f $git.uncommitted)
}
$lines += ""
$lines += "## PROGRESS BREAKDOWN"
$lines += ("- Infrastructure & Setup: {0}%" -f $progress.details.infrastructure)
$lines += ("- Reporting System: {0}%" -f $progress.details.reporting)
$lines += ("- Security Baseline: {0}%" -f $progress.details.security)
$lines += ("- Documentation: {0}%" -f $progress.details.documentation)
$lines += ("- Testing Framework: {0}%" -f $progress.details.testing)
$lines += ("- Deployment Pipeline: {0}%" -f $progress.details.deployment)
$lines += ""
$lines += "## ROADMAP (REALISTIC)"
$lines += "PHASE 1 (1-2 weeks): Foundation"
$lines += "- Initialize Git + .gitignore"
$lines += "- Confirm Gradle wrapper (gradlew/gradlew.bat) or regenerate"
$lines += "- Add docs/ARCHITECTURE.md + improve README"
$lines += ""
$lines += "PHASE 2 (3-4 weeks): Security Core"
$lines += "- Implement Android Keystore + AES-GCM storage"
$lines += "- Define threat model + logging redaction"
$lines += "- Basic auth flow + secure settings"
$lines += ""
$lines += "PHASE 3 (2-4 weeks): Quality & UX"
$lines += "- Unify UI approach (Compose vs XML)"
$lines += "- Add unit + instrumentation tests"
$lines += "- Stabilize camera/biometrics flows"
$lines += ""
$lines += "PHASE 4 (2-3 weeks): Release Readiness"
$lines += "- CI pipeline + signing strategy"
$lines += "- Beta testing + crash monitoring"
$lines += "- Performance hardening"
$lines += ""
$lines += "## METRICS"
$lines += ("- Total project files: {0}" -f $totalFiles)
$lines += ("- Total size: {0} MB" -f $totalSizeMB)
$lines += ("- Last modified (root): {0}" -f $lastModified)
$lines += ("- Project age: {0} days" -f $ageDays)
$lines += ""
$lines += "## QUICK COMMANDS"
$lines += ("cd ""{0}""" -f $ProjectRoot)
$lines += "powershell -NoProfile -ExecutionPolicy Bypass -File ""reports\generate_final_status_report.ps1"""

$contentTxt = ($lines -join "`r`n")
$contentTxt | Out-File -FilePath $txtPath -Encoding UTF8

# HTML: show the same report in a clickable copy block (and two quick-copy command blocks).
$escaped = ($lines -join "`n") -replace "&","&amp;" -replace "<","&lt;" -replace ">","&gt;"
$gitCmds = ("cd ""{0}""`n" -f $ProjectRoot) + "git init`n" + "git add .`n" + "git commit -m ""Initial: VaultGuard v1.0"""
$gitCmdsEsc = $gitCmds -replace "&","&amp;" -replace "<","&lt;" -replace ">","&gt;"
$buildCmds = ("cd ""{0}""`n" -f $ProjectRoot) + ".\\gradlew.bat clean assembleDebug"
$buildCmdsEsc = $buildCmds -replace "&","&amp;" -replace "<","&lt;" -replace ">","&gt;"

$html = @"
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>VaultGuard - Final Status & Roadmap ($timestamp)</title>
    <style>
      body { font-family: Segoe UI, Arial, sans-serif; margin: 20px; background: #0b1020; color: #e8eefc; }
      .wrap { max-width: 1100px; margin: 0 auto; }
      .row { display: flex; gap: 10px; flex-wrap: wrap; align-items: center; }
      .btn { cursor: pointer; border: 1px solid rgba(255,255,255,.18); border-radius: 10px; padding: 10px 12px; background: rgba(255,255,255,.06); color: #e8eefc; font-weight: 800; letter-spacing: .4px; text-transform: uppercase; }
      .btn:hover { border-color: rgba(102,227,255,.55); }
      .status { color: rgba(232,238,252,.75); font-size: 12px; }
      .block { margin-top: 14px; border: 1px solid rgba(102,227,255,.35); border-radius: 12px; background: rgba(0,0,0,.22); padding: 12px; cursor: pointer; }
      .block:hover { border-color: rgba(102,227,255,.55); }
      pre { margin: 0; white-space: pre-wrap; word-break: break-word; font-family: Consolas, "Courier New", monospace; font-size: 12.5px; line-height: 1.45; }
      h1 { margin: 8px 0 0; font-size: 18px; }
      .hint { margin-top: 8px; color: rgba(232,238,252,.70); font-size: 12px; }
      .tag { display: inline-block; padding: 6px 10px; border: 1px solid rgba(255,255,255,.14); border-radius: 999px; background: rgba(0,0,0,.18); font-size: 12px; color: rgba(232,238,252,.80); }
    </style>
  </head>
  <body>
    <div class="wrap">
      <div class="row">
        <button class="btn" id="copyReportBtn" type="button">CLICK TO COPY REPORT</button>
        <button class="btn" id="copyGitBtn" type="button">COPY GIT INIT</button>
        <button class="btn" id="copyBuildBtn" type="button">COPY BUILD CMD</button>
        <span id="copyStatus" class="status"></span>
      </div>
      <h1>VaultGuard - Final Status & Roadmap</h1>
      <div class="hint"><span class="tag">Tip</span> Click anywhere inside a block to copy its content.</div>

      <div class="block" id="reportBlock" role="button" tabindex="0" title="Click to copy full report">
        <pre id="reportText">$escaped</pre>
      </div>

      <div class="block" id="gitBlock" role="button" tabindex="0" title="Click to copy git init commands">
        <pre id="gitText">$gitCmdsEsc</pre>
      </div>

      <div class="block" id="buildBlock" role="button" tabindex="0" title="Click to copy build command">
        <pre id="buildText">$buildCmdsEsc</pre>
      </div>
    </div>
    <script>
      const status = document.getElementById('copyStatus');
      function setStatus(msg) { status.textContent = msg; setTimeout(()=>status.textContent='', 1600); }
      async function copyToClipboard(t) {
        if (navigator.clipboard && navigator.clipboard.writeText) { await navigator.clipboard.writeText(t); return; }
        const tmp = document.createElement('textarea'); tmp.value = t; tmp.setAttribute('readonly','true');
        tmp.style.position='fixed'; tmp.style.opacity='0'; document.body.appendChild(tmp); tmp.focus(); tmp.select();
        const ok = document.execCommand('copy'); document.body.removeChild(tmp);
        if (!ok) throw new Error('fallback failed');
      }
      function wire(blockId, textId, okMsg) {
        const block = document.getElementById(blockId);
        const text = document.getElementById(textId).textContent;
        async function doCopy() { try { await copyToClipboard(text); setStatus(okMsg); } catch (e) { setStatus('Copy failed'); } }
        block.addEventListener('click', doCopy);
        block.addEventListener('keydown', (e)=>{ if (e.key==='Enter' || e.key===' ') { e.preventDefault(); doCopy(); } });
        return doCopy;
      }
      const copyReport = wire('reportBlock','reportText','Report copied');
      const copyGit = wire('gitBlock','gitText','Git commands copied');
      const copyBuild = wire('buildBlock','buildText','Build command copied');
      document.getElementById('copyReportBtn').addEventListener('click', copyReport);
      document.getElementById('copyGitBtn').addEventListener('click', copyGit);
      document.getElementById('copyBuildBtn').addEventListener('click', copyBuild);
    </script>
  </body>
</html>
"@

$html | Out-File -FilePath $htmlPath -Encoding UTF8

Write-Output "Final status report generated."
Write-Output ("TXT: {0}" -f $txtPath)
Write-Output ("HTML: {0}" -f $htmlPath)

# Also write deterministic "LATEST" files for easy linking and Git tracking.
$latestTxt = Join-Path $reportsDir "VAULTGUARD_FINAL_STATUS_ROADMAP_LATEST.txt"
$latestHtml = Join-Path $reportsDir "VAULTGUARD_FINAL_STATUS_ROADMAP_LATEST.html"
try { Copy-Item -LiteralPath $txtPath -Destination $latestTxt -Force } catch { }
try { Copy-Item -LiteralPath $htmlPath -Destination $latestHtml -Force } catch { }

if ($OpenReports) {
  try { Start-Process $htmlPath | Out-Null } catch { }
  try { Start-Process notepad -ArgumentList ("`"{0}`"" -f $txtPath) | Out-Null } catch { }
}

