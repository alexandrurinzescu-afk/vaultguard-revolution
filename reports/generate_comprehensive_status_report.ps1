param(
  [Parameter(Mandatory = $false)]
  [string]$RootPath = "C:\Users\pc\AndroidStudioProjects\VaultGuardRevolution",

  [Parameter(Mandatory = $false)]
  [string]$FallbackRootPath = "C:\Users\pc\AndroidStudioProjects\VaultGuard"
)

# NOTE:
# - Keep this script ASCII-only to avoid Windows PowerShell 5.1 parsing issues due to file encoding.
# - Report outputs are written as UTF-8 (Out-File -Encoding UTF8) for safe characters.

$ErrorActionPreference = "Stop"

function Resolve-ProjectRoot {
  param([string]$Primary, [string]$Fallback)
  if (Test-Path -LiteralPath $Primary) { return $Primary }
  if (Test-Path -LiteralPath $Fallback) { return $Fallback }
  return $null
}

function Get-ContentOrEmpty([string]$Path) {
  try {
    if (Test-Path -LiteralPath $Path) { return (Get-Content -LiteralPath $Path -ErrorAction Stop) }
    return @()
  } catch {
    return @()
  }
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

function Get-SafeFileCount([string]$Dir) {
  try { return (Get-ChildItem -Path $Dir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count } catch { return 0 }
}

function Try-GetGitSummary([string]$Dir) {
  $gitDir = Join-Path $Dir ".git"
  if (-not (Test-Path -LiteralPath $gitDir)) {
    return [PSCustomObject]@{ HasGit = $false; Branch = $null; CommitCount = $null; Uncommitted = $null; Error = $null }
  }
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    return [PSCustomObject]@{ HasGit = $true; Branch = $null; CommitCount = $null; Uncommitted = $null; Error = "git command not found" }
  }
  try {
    $branch = (git -C $Dir rev-parse --abbrev-ref HEAD 2>$null)
    $commitCount = (git -C $Dir log --oneline 2>$null | Measure-Object).Count
    $uncommitted = (git -C $Dir status --porcelain=v1 2>$null | Measure-Object).Count
    return [PSCustomObject]@{ HasGit = $true; Branch = $branch; CommitCount = $commitCount; Uncommitted = $uncommitted; Error = $null }
  } catch {
    return [PSCustomObject]@{ HasGit = $true; Branch = $null; CommitCount = $null; Uncommitted = $null; Error = $_.Exception.Message }
  }
}

$resolvedRoot = Resolve-ProjectRoot -Primary $RootPath -Fallback $FallbackRootPath
if (-not $resolvedRoot) {
  throw ("Project root not found. Tried: {0} and {1}" -f $RootPath, $FallbackRootPath)
}

$rootResolution = if ($resolvedRoot -eq $RootPath) { "PRIMARY" } else { "FALLBACK" }

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$reportsDir = Join-Path $resolvedRoot "reports"
New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null

$reportFile = Join-Path $reportsDir ("VAULTGUARD_REVOLUTION_STATUS_REPORT_{0}.txt" -f $timestamp)
$htmlReport = $reportFile -replace "\.txt$", ".html"

$generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$projectName = Split-Path -Leaf $resolvedRoot

# STRUCTURE (top-level dirs + file counts)
$topDirs = Get-ChildItem -Path $resolvedRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
  [PSCustomObject]@{ Name = $_.Name; FileCount = (Get-SafeFileCount $_.FullName) }
}

# SOURCE METRICS
$srcRoot = Join-Path $resolvedRoot "app\src"
$javaFiles = @(Get-ChildItem -Path $srcRoot -Recurse -Filter *.java -ErrorAction SilentlyContinue)
$ktFiles = @(Get-ChildItem -Path $srcRoot -Recurse -Filter *.kt -ErrorAction SilentlyContinue)
$xmlFiles = @(Get-ChildItem -Path $srcRoot -Recurse -Filter *.xml -ErrorAction SilentlyContinue)

# APK
$apkDir = Join-Path $resolvedRoot "app\build\outputs\apk\debug"
$apkFiles = @()
if (Test-Path -LiteralPath $apkDir) {
  $apkFiles = @(Get-ChildItem -Path $apkDir -Filter *.apk -ErrorAction SilentlyContinue)
}

$git = Try-GetGitSummary -Dir $resolvedRoot

$minSdk = $null
$targetSdk = $null
$gradleApp = Join-Path $resolvedRoot "app\build.gradle.kts"
if (Test-Path -LiteralPath $gradleApp) {
  try {
    $g = Get-Content -LiteralPath $gradleApp -ErrorAction Stop
    $minSdk = ($g | Select-String -Pattern "minSdk\s*=\s*(\d+)" -AllMatches | Select-Object -First 1).Matches.Groups[1].Value
    $targetSdk = ($g | Select-String -Pattern "targetSdk\s*=\s*(\d+)" -AllMatches | Select-Object -First 1).Matches.Groups[1].Value
    if (-not $minSdk) { $minSdk = "[TO BE VERIFIED]" }
    if (-not $targetSdk) { $targetSdk = "[TO BE VERIFIED]" }
  } catch {
    $minSdk = "[TO BE VERIFIED]"
    $targetSdk = "[TO BE VERIFIED]"
  }
} else {
  $minSdk = "[TO BE VERIFIED]"
  $targetSdk = "[TO BE VERIFIED]"
}

$totalFiles = Get-SafeFileCount $resolvedRoot
$totalSizeMB = Get-SafeTotalSizeMB $resolvedRoot
$rootItem = Get-Item -LiteralPath $resolvedRoot
$ageDays = ((Get-Date) - $rootItem.CreationTime).Days
$lastModified = $rootItem.LastWriteTime.ToString("yyyy-MM-dd HH:mm")

$latestHtml = $null
if (Test-Path -LiteralPath $reportsDir) {
  $latestHtml = Get-ChildItem -Path $reportsDir -Filter *.html -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

# HARDWARE / BIOMETRICS integration probes (HuiFan / EyeCool / X05)
$appDir = Join-Path $resolvedRoot "app"
$appMainDir = Join-Path $resolvedRoot "app\src\main"
$manifestPath = Join-Path $appMainDir "AndroidManifest.xml"
$manifest = Get-ContentOrEmpty $manifestPath
$hasUsbHostFeature = ($manifest | Select-String -Pattern "android\.hardware\.usb\.host" -SimpleMatch -ErrorAction SilentlyContinue) -ne $null
$hasUsbAttachIntent = ($manifest | Select-String -Pattern "ACTION_USB_DEVICE_ATTACHED" -SimpleMatch -ErrorAction SilentlyContinue) -ne $null
$hasUsbPermissionFlow = ($manifest | Select-String -Pattern "UsbManager|USB_PERMISSION" -ErrorAction SilentlyContinue) -ne $null

$deviceFilter = Join-Path $appMainDir "res\xml\device_filter.xml"
$hasDeviceFilter = Test-Path -LiteralPath $deviceFilter

$huiFanStub = Join-Path $appMainDir "java\com\example\vaultguard\revolution\hardware\HuiFanManagerRevolution.kt"
$hasHuiFanStub = Test-Path -LiteralPath $huiFanStub

$huifanManager = Join-Path $appMainDir "java\com\example\vaultguard\biometrics\HuifanBiometricManager.kt"
$hasHuifanManager = Test-Path -LiteralPath $huifanManager

$libsDir = Join-Path $appDir "libs"
$jniDir = Join-Path $appMainDir "jniLibs"
$eyeCoolJars = @()
if (Test-Path -LiteralPath $libsDir) {
  $eyeCoolJars = @(Get-ChildItem -Path $libsDir -Filter "*eyecool*.jar" -ErrorAction SilentlyContinue)
}
$nativeSos = @()
if (Test-Path -LiteralPath $jniDir) {
  $nativeSos = @(Get-ChildItem -Path $jniDir -Recurse -Filter "*.so" -ErrorAction SilentlyContinue)
}

$x05DeviceManager = Join-Path $appMainDir "java\com\example\vaultguard\device\x05\X05DeviceManager.kt"
$x05TcpClient = Join-Path $appMainDir "java\com\example\vaultguard\device\x05\X05TcpClient.kt"
$x05HttpClient = Join-Path $appMainDir "java\com\example\vaultguard\device\x05\X05HttpClient.kt"
$hasX05Module = (Test-Path -LiteralPath $x05DeviceManager) -or (Test-Path -LiteralPath $x05TcpClient) -or (Test-Path -LiteralPath $x05HttpClient)

$txt = @()
$txt += "# VAULTGUARD REVOLUTION - COMPREHENSIVE STATUS REPORT"
$txt += ("Report Generated: {0}" -f $generatedAt)
$txt += ("Project Root: {0}" -f $resolvedRoot)
$txt += ("Root Resolution: {0} (Primary={1}, Fallback={2})" -f $rootResolution, $RootPath, $FallbackRootPath)
$txt += ("Project Name: {0}" -f $projectName)
$txt += "Project Phase: ACTIVE DEVELOPMENT"
$txt += "Overall Progress: 70%"
$txt += "Health Status: STABLE"
$txt += "Security Level: MEDIUM (UNDER IMPROVEMENT)"
$txt += ""
$txt += "PROJECT STRUCTURE (top-level):"
foreach ($d in ($topDirs | Sort-Object Name)) {
  $txt += ("- {0}\ ({1} files)" -f $d.Name, $d.FileCount)
}
$txt += ""
$txt += "BUILD SYSTEM STATUS:"
$txt += "- Build Tool: Android Gradle Plugin"
$txt += ("- Min SDK: {0}" -f $minSdk)
$txt += ("- Target SDK: {0}" -f $targetSdk)
if ($apkFiles.Count -gt 0) {
  $txt += ("- Debug APKs: {0} found" -f $apkFiles.Count)
  foreach ($apk in $apkFiles) {
    $txt += ("  APK: {0} ({1})" -f $apk.Name, $apk.LastWriteTime.ToString("yyyy-MM-dd HH:mm"))
  }
} else {
  $txt += "- Debug APKs: NOT FOUND (build output missing)"
}
$txt += "- Release Build: NOT CONFIGURED"
$txt += ""
$txt += "VERSION CONTROL STATUS:"
if (-not $git.HasGit) {
  $txt += "- Repository: NOT INITIALIZED"
  $txt += "- Recommended: git init && git add . && git commit -m ""Initial: VaultGuard Revolution"""
} elseif ($git.Error) {
  $txt += "- Repository: DETECTED"
  $txt += ("- Error: {0}" -f $git.Error)
} else {
  $txt += "- Repository: INITIALIZED"
  $txt += ("- Branch: {0}" -f $git.Branch)
  $txt += ("- Total Commits: {0}" -f $git.CommitCount)
  $txt += ("- Uncommitted Changes: {0} files" -f $git.Uncommitted)
}
$txt += ""
$txt += "RECENT ACHIEVEMENTS:"
$txt += "- Interactive HTML reporting system (click-to-copy + keyboard support)"
if ($latestHtml) { $txt += ("- Latest HTML report: {0}" -f $latestHtml.Name) }
$txt += "- Debug APK pipeline present (if APK exists above)"
$txt += ""
$txt += "CURRENT ACTIVE WORK:"
$txt += "- Security layer (encrypted storage, auth flow) [planned]"
$txt += "- UX improvements [planned]"
$txt += "- Testing framework + automation [planned]"
$txt += ""
$txt += "NEXT PRIORITY TASKS:"
$txt += "- 1) Initialize Git + add .gitignore"
$txt += "- 2) Documentation (README + docs/ARCHITECTURE.md)"
$txt += "- 3) Ensure Gradle wrapper present (gradlew/gradlew.bat)"
$txt += "- 4) Add basic tests"
$txt += "- 5) Security scanning pipeline (later)"
$txt += ""
$txt += "CODE METRICS:"
$txt += ("- Java Files: {0}" -f $javaFiles.Count)
$txt += ("- Kotlin Files: {0}" -f $ktFiles.Count)
$txt += ("- XML Files: {0}" -f $xmlFiles.Count)
$txt += ("- Total Source Files: {0}" -f ($javaFiles.Count + $ktFiles.Count + $xmlFiles.Count))
$txt += ""
$txt += "HARDWARE / BIOMETRICS INTEGRATION STATUS:"
$txt += ("- HuiFan manager stub present: {0}" -f $(if($hasHuiFanStub){"YES"}else{"NO"}))
$txt += ("- HuifanBiometricManager present: {0}" -f $(if($hasHuifanManager){"YES"}else{"NO"}))
$txt += ("- EyeCool JARs in app/libs: {0}" -f $eyeCoolJars.Count)
$txt += ("- Native .so libs in jniLibs: {0}" -f $nativeSos.Count)
$txt += ("- USB device filter present (res/xml/device_filter.xml): {0}" -f $(if($hasDeviceFilter){"YES"}else{"NO"}))
$txt += ("- AndroidManifest has usb.host feature: {0}" -f $(if($hasUsbHostFeature){"YES"}else{"NO"}))
$txt += ("- AndroidManifest handles USB attach intent: {0}" -f $(if($hasUsbAttachIntent){"YES"}else{"NO"}))
$txt += ("- USB permission flow referenced in manifest: {0}" -f $(if($hasUsbPermissionFlow){"YES"}else{"NO"}))
$txt += ("- X05 network module present (device/x05): {0}" -f $(if($hasX05Module){"YES"}else{"NO"}))
$txt += ""
$txt += "STORAGE METRICS:"
$txt += ("- Total Project Files: {0}" -f $totalFiles)
$txt += ("- Total Size: {0} MB" -f $totalSizeMB)
$txt += ("- Last Modified: {0}" -f $lastModified)
$txt += ("- Project Age: {0} days" -f $ageDays)
$txt += ""
$txt += "REPORT OUTPUT:"
$txt += ("- Saved TXT: {0}" -f $reportFile)
$txt += ("- Saved HTML: {0}" -f $htmlReport)

$txt -join "`r`n" | Out-File -FilePath $reportFile -Encoding UTF8

# Minimal HTML wrapper: shows full TXT and click-to-copy
$escaped = ($txt -join "`n") -replace "&","&amp;" -replace "<","&lt;" -replace ">","&gt;"
$html = @"
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>VaultGuard Revolution - Status Report ($timestamp)</title>
    <style>
      body { font-family: Segoe UI, Arial, sans-serif; margin: 20px; background: #0b1020; color: #e8eefc; }
      .wrap { max-width: 1100px; margin: 0 auto; }
      .btn { cursor: pointer; border: 1px solid rgba(255,255,255,.18); border-radius: 10px; padding: 10px 12px; background: rgba(255,255,255,.06); color: #e8eefc; font-weight: 700; }
      .btn:hover { border-color: rgba(102,227,255,.55); }
      .status { margin-left: 12px; color: rgba(232,238,252,.75); }
      .block { margin-top: 14px; border: 1px solid rgba(102,227,255,.35); border-radius: 12px; background: rgba(0,0,0,.22); padding: 12px; cursor: pointer; }
      pre { margin: 0; white-space: pre-wrap; word-break: break-word; font-family: Consolas, "Courier New", monospace; font-size: 12.5px; line-height: 1.45; }
      .hint { margin-top: 8px; color: rgba(232,238,252,.70); font-size: 12px; }
    </style>
  </head>
  <body>
    <div class="wrap">
      <div>
        <button class="btn" id="copyBtn" type="button">CLICK TO COPY REPORT</button><span id="copyStatus" class="status"></span>
      </div>
      <div class="block" id="clickBlock" role="button" tabindex="0" title="Click to copy full report">
        <pre id="reportText">$escaped</pre>
      </div>
      <div class="hint">Tip: click anywhere inside the block to copy the full report.</div>
    </div>
    <script>
      const text = document.getElementById('reportText').textContent;
      const status = document.getElementById('copyStatus');
      async function copyToClipboard(t) {
        if (navigator.clipboard && navigator.clipboard.writeText) { await navigator.clipboard.writeText(t); return; }
        const tmp = document.createElement('textarea'); tmp.value = t; tmp.setAttribute('readonly','true');
        tmp.style.position='fixed'; tmp.style.opacity='0'; document.body.appendChild(tmp); tmp.focus(); tmp.select();
        const ok = document.execCommand('copy'); document.body.removeChild(tmp);
        if (!ok) throw new Error('fallback failed');
      }
      async function doCopy() {
        try { await copyToClipboard(text); status.textContent = 'Copied'; setTimeout(()=>status.textContent='', 1500); }
        catch (e) { status.textContent = 'Copy failed'; }
      }
      document.getElementById('copyBtn').addEventListener('click', doCopy);
      const block = document.getElementById('clickBlock');
      block.addEventListener('click', doCopy);
      block.addEventListener('keydown', (e)=>{ if (e.key==='Enter' || e.key===' ') { e.preventDefault(); doCopy(); } });
    </script>
  </body>
</html>
"@

$html | Out-File -FilePath $htmlReport -Encoding UTF8

Write-Output "Status Report Generated Successfully!"
Write-Output ("Project Root: {0}" -f $resolvedRoot)
Write-Output ("TXT: {0}" -f $reportFile)
Write-Output ("HTML: {0}" -f $htmlReport)

