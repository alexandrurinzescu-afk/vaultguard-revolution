param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = "C:\Users\pc\AndroidStudioProjects\VaultGuard"
)

# Interim status report generator (TXT + HTML).
# ASCII-only script for Windows PowerShell 5.1 stability.

$ErrorActionPreference = "Stop"

function Ensure-Dir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function Append-Line([string]$Path, [string]$Text) {
  $Text | Out-File -FilePath $Path -Append -Encoding UTF8
}

function Now-Local([string]$tzId) {
  $tz = [TimeZoneInfo]::FindSystemTimeZoneById($tzId)
  return [TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, $tz)
}

if (-not (Test-Path -LiteralPath $ProjectRoot)) {
  throw ("Project root not found: {0}" -f $ProjectRoot)
}

Set-Location -LiteralPath $ProjectRoot

$reportsDir = Join-Path $ProjectRoot "reports"
$docsDir = Join-Path $ProjectRoot "docs"
Ensure-Dir $reportsDir
Ensure-Dir $docsDir

$tzId = "Central European Standard Time"
$nowCET = Now-Local $tzId
$ts = $nowCET.ToString("yyyyMMdd_HHmmss")

$txt = Join-Path $reportsDir ("INTERIM_STATUS_REPORT_{0}.txt" -f $ts)
$html = $txt -replace "\.txt$", ".html"

$totalFiles = (Get-ChildItem -Path $ProjectRoot -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
$reportFiles = (Get-ChildItem -Path $reportsDir -File -ErrorAction SilentlyContinue | Measure-Object).Count
$sourceFiles = (Get-ChildItem -Path (Join-Path $ProjectRoot "app\src") -Recurse -File -Include *.java,*.kt,*.xml -ErrorAction SilentlyContinue | Measure-Object).Count

$apkDir = Join-Path $ProjectRoot "app\build\outputs\apk\debug"
$apkList = @()
if (Test-Path -LiteralPath $apkDir) {
  $apkList = @(Get-ChildItem -Path $apkDir -Filter *.apk -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
}

$checkpoints = @(Get-ChildItem -Path $reportsDir -Filter "execution_checkpoint_*.txt" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
$latestCheckpoint = $null
if ($checkpoints.Count -gt 0) { $latestCheckpoint = $checkpoints[0] }

$buildLogs = @(Get-ChildItem -Path $reportsDir -Filter "BUILD_LOG_*.txt" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
$secReports = @(Get-ChildItem -Path $reportsDir -Filter "SECURITY_ANALYSIS_*.txt" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
$finalReports = @(Get-ChildItem -Path $reportsDir -Filter "FINAL_EXECUTION_REPORT_*.txt" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)

$phase = "UNKNOWN"
if ($latestCheckpoint) { $phase = "PHASE 1 (analysis) OR LATER" }
if ($buildLogs.Count -gt 0) { $phase = "PHASE 2 (build/test) OR LATER" }
if ($secReports.Count -gt 0) { $phase = "PHASE 3 (security) OR LATER" }
if ($finalReports.Count -gt 0 -and $finalReports[0].LastWriteTime -gt $nowCET.AddHours(-6)) { $phase = "FINALIZED (recent final report exists)" }

$javaProcs = @(Get-Process | Where-Object { $_.ProcessName -match "java|gradle" } | Sort-Object CPU -Descending | Select-Object -First 20)

@"
VAULTGUARD INTERIM STATUS REPORT
===============================
Generated (CET): $($nowCET.ToString("yyyy-MM-dd HH:mm:ss"))
Project: $ProjectRoot

1) COUNTS
- Total files: $totalFiles
- Source files (java/kt/xml): $sourceFiles
- Reports files: $reportFiles

2) CURRENT PHASE (heuristic)
$phase

3) APK STATUS
"@ | Out-File -FilePath $txt -Encoding UTF8

if ($apkList.Count -gt 0) {
  Append-Line $txt ("- Debug APK count: {0}" -f $apkList.Count)
  foreach ($apk in ($apkList | Select-Object -First 3)) {
    $sizeMB = [math]::Round($apk.Length / 1MB, 2)
    Append-Line $txt ("  - {0} ({1} MB, {2})" -f $apk.Name, $sizeMB, $apk.LastWriteTime.ToString("yyyy-MM-dd HH:mm"))
  }
} else {
  Append-Line $txt "- Debug APKs: none found"
}

Append-Line $txt ""
Append-Line $txt "4) LATEST CHECKPOINT"
if ($latestCheckpoint) {
  Append-Line $txt ("- {0} ({1})" -f $latestCheckpoint.Name, $latestCheckpoint.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss"))
  Append-Line $txt "----"
  (Get-Content -LiteralPath $latestCheckpoint.FullName -ErrorAction SilentlyContinue) | ForEach-Object { Append-Line $txt $_ }
  Append-Line $txt "----"
} else {
  Append-Line $txt "- none"
}

Append-Line $txt ""
Append-Line $txt "5) RECENT ARTIFACTS (reports/)"
Get-ChildItem -Path $reportsDir -File -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 12 |
  ForEach-Object { Append-Line $txt ("- {0} ({1})" -f $_.Name, $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")) }

Append-Line $txt ""
Append-Line $txt "6) BUILD/SECURITY LOGS (latest)"
if ($buildLogs.Count -gt 0) { Append-Line $txt ("- BUILD_LOG: {0}" -f $buildLogs[0].Name) } else { Append-Line $txt "- BUILD_LOG: none" }
if ($secReports.Count -gt 0) { Append-Line $txt ("- SECURITY_ANALYSIS: {0}" -f $secReports[0].Name) } else { Append-Line $txt "- SECURITY_ANALYSIS: none" }
if ($finalReports.Count -gt 0) { Append-Line $txt ("- FINAL_EXECUTION_REPORT: {0}" -f $finalReports[0].Name) } else { Append-Line $txt "- FINAL_EXECUTION_REPORT: none (yet)" }

Append-Line $txt ""
Append-Line $txt "7) RUNNING JAVA/GRADLE PROCESSES (top 20)"
if ($javaProcs.Count -gt 0) {
  foreach ($p in $javaProcs) { Append-Line $txt ("- {0} pid={1} cpu={2}" -f $p.ProcessName, $p.Id, $p.CPU) }
} else {
  Append-Line $txt "- none"
}

Append-Line $txt ""
Append-Line $txt "8) RECOMMENDED NEXT STEPS"
Append-Line $txt "- If still before 09:00 CET: wait for FINAL_EXECUTION_REPORT and backup to be generated."
Append-Line $txt "- Review BUILD_LOG and SECURITY_ANALYSIS for warnings/errors."
Append-Line $txt "- If you need to stop early: run remote_execution_scheduled.ps1 with -NoWaitUntilStop."

# Minimal HTML wrapper (click-to-copy)
$escaped = (Get-Content -LiteralPath $txt -Raw) -replace "&","&amp;" -replace "<","&lt;" -replace ">","&gt;"
$htmlBody = @"
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>VaultGuard Interim Status Report</title>
    <style>
      body { font-family: Segoe UI, Arial, sans-serif; margin: 20px; background: #0b1020; color: #e8eefc; }
      .wrap { max-width: 1100px; margin: 0 auto; }
      .btn { cursor: pointer; border: 1px solid rgba(255,255,255,.18); border-radius: 10px; padding: 10px 12px; background: rgba(255,255,255,.06); color: #e8eefc; font-weight: 800; letter-spacing: .4px; text-transform: uppercase; }
      .btn:hover { border-color: rgba(102,227,255,.55); }
      .status { color: rgba(232,238,252,.75); font-size: 12px; margin-left: 10px; }
      .block { margin-top: 14px; border: 1px solid rgba(102,227,255,.35); border-radius: 12px; background: rgba(0,0,0,.22); padding: 12px; cursor: pointer; }
      pre { margin: 0; white-space: pre-wrap; word-break: break-word; font-family: Consolas, "Courier New", monospace; font-size: 12.5px; line-height: 1.45; }
      .hint { margin-top: 8px; color: rgba(232,238,252,.70); font-size: 12px; }
    </style>
  </head>
  <body>
    <div class="wrap">
      <button class="btn" id="copyBtn" type="button">CLICK TO COPY</button><span id="copyStatus" class="status"></span>
      <div class="block" id="block" role="button" tabindex="0" title="Click to copy">
        <pre id="text">$escaped</pre>
      </div>
      <div class="hint">Tip: click anywhere inside the block to copy the full report.</div>
    </div>
    <script>
      const status = document.getElementById('copyStatus');
      async function copyToClipboard(t) {
        if (navigator.clipboard && navigator.clipboard.writeText) { await navigator.clipboard.writeText(t); return; }
        const tmp = document.createElement('textarea'); tmp.value = t; tmp.setAttribute('readonly','true');
        tmp.style.position='fixed'; tmp.style.opacity='0'; document.body.appendChild(tmp); tmp.focus(); tmp.select();
        const ok = document.execCommand('copy'); document.body.removeChild(tmp);
        if (!ok) throw new Error('fallback failed');
      }
      async function doCopy() {
        try { await copyToClipboard(document.getElementById('text').textContent); status.textContent='Copied'; setTimeout(()=>status.textContent='',1500); }
        catch (e) { status.textContent='Copy failed'; }
      }
      document.getElementById('copyBtn').addEventListener('click', doCopy);
      const block = document.getElementById('block');
      block.addEventListener('click', doCopy);
      block.addEventListener('keydown', (e)=>{ if (e.key==='Enter' || e.key===' ') { e.preventDefault(); doCopy(); } });
    </script>
  </body>
</html>
"@

$htmlBody | Out-File -FilePath $html -Encoding UTF8

Write-Output ("TXT: {0}" -f $txt)
Write-Output ("HTML: {0}" -f $html)

