param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = "",

  [Parameter(Mandatory = $true)]
  [string]$Command,

  [Parameter(Mandatory = $false)]
  [string]$Label = "EXEC",

  [Parameter(Mandatory = $false)]
  [int]$TailLines = 60,

  [Parameter(Mandatory = $false)]
  [switch]$Live
)

# Compact command runner for Cursor chat/terminal:
# - Saves full output to chat_history/*.log
# - Prints only a compact status report + last N lines (default)
# - Archives previous "latest" status automatically
# - Tries to summarize latest Debug APK (name/size/path) when available
# ASCII-only script for Windows PowerShell 5.1 parsing stability.

$ErrorActionPreference = "Stop"

function Ensure-Dir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function Html-Encode([string]$s) {
  # PowerShell 5.1 friendly HTML encode
  return [System.Net.WebUtility]::HtmlEncode($s)
}

function Section([string]$Title) {
  Write-Host ""
  Write-Host ("=" * 80) -ForegroundColor DarkGray
  Write-Host $Title -ForegroundColor Cyan
  Write-Host ("=" * 80) -ForegroundColor DarkGray
}

function Format-Duration([TimeSpan]$ts) {
  if ($ts.TotalHours -ge 1) { return ("{0}h {1}m {2}s" -f [int]$ts.TotalHours, $ts.Minutes, $ts.Seconds) }
  if ($ts.TotalMinutes -ge 1) { return ("{0}m {1}s" -f $ts.Minutes, $ts.Seconds) }
  return ("{0}s" -f $ts.Seconds)
}

function Try-GetLatestDebugApk([string]$ProjectRootPath) {
  $apkDir = Join-Path $ProjectRootPath "app\build\outputs\apk\debug"
  if (-not (Test-Path -LiteralPath $apkDir)) { return $null }
  $apks = @(Get-ChildItem -Path $apkDir -Filter *.apk -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
  if ($apks.Count -eq 0) { return $null }
  return $apks[0]
}

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

if (-not (Test-Path -LiteralPath $ProjectRoot)) {
  throw ("Project root not found: {0}" -f $ProjectRoot)
}

Set-Location -LiteralPath $ProjectRoot

$historyDir = Join-Path $ProjectRoot "chat_history"
$reportsDir = Join-Path $ProjectRoot "reports"
Ensure-Dir $historyDir
Ensure-Dir $reportsDir

# Archive previous latest status (so chat stays focused on "current")
$latestStatusPath = Join-Path $reportsDir "CHAT_STATUS_LATEST.txt"
if (Test-Path -LiteralPath $latestStatusPath) {
  $archTs = Get-Date -Format "yyyyMMdd_HHmmss"
  $archPath = Join-Path $historyDir ("CHAT_STATUS_{0}.txt" -f $archTs)
  try { Move-Item -LiteralPath $latestStatusPath -Destination $archPath -Force } catch { }
}

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$safeLabel = ($Label -replace "[^A-Za-z0-9_\-]", "_")
$logPath = Join-Path $historyDir ("{0}_{1}.log" -f $safeLabel, $ts)

if ($TailLines -lt 0) { $TailLines = 0 }

# PAS 1: "Clear chat"
Clear-Host

# PAS 2: Show current command
Section "CURSOR CLEAN EXECUTION"
Write-Host ("Time:     {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
Write-Host ("Project:  {0}" -f $ProjectRoot)
Write-Host ("Command:  {0}" -f $Command) -ForegroundColor White
Write-Host ("Log file: {0}" -f $logPath) -ForegroundColor DarkYellow
Write-Host ("Mode:     {0}" -f ($(if ($Live) { "LIVE (full output streamed)" } else { "COMPACT (tail only)" })))

$start = Get-Date
$exitCode = $null
$status = "UNKNOWN"
$apk = $null

try {
  # PAS 3: Run command
  Section "RUNNING"

  if ($Live) {
    # Live output (can be noisy): stream to screen and copy to log.
    cmd.exe /d /c $Command 2>&1 | Tee-Object -FilePath $logPath
    $exitCode = $LASTEXITCODE
  } else {
    # Quiet run: capture everything, then show only the tail.
    cmd.exe /d /c $Command *> $logPath
    $exitCode = $LASTEXITCODE

    if ($TailLines -gt 0) {
      Section ("OUTPUT TAIL (last {0} lines)" -f $TailLines)
      try { Get-Content -LiteralPath $logPath -Tail $TailLines -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ } } catch { }
    }
  }

  if ($exitCode -eq 0) { $status = "SUCCESS" } else { $status = ("FAIL (exit {0})" -f $exitCode) }
}
catch {
  $status = "FAIL (exception)"
}
finally {
  $end = Get-Date
  $dur = New-TimeSpan -Start $start -End $end

  if ($status -eq "SUCCESS") {
    $apk = Try-GetLatestDebugApk -ProjectRootPath $ProjectRoot
  }

  $apkSummary = "n/a"
  $apkPath = ""
  $apkInstall = ""
  if ($apk) {
    $sizeMB = [math]::Round($apk.Length / 1MB, 2)
    $apkSummary = ("{0} ({1} MB, {2})" -f $apk.Name, $sizeMB, $apk.LastWriteTime.ToString("yyyy-MM-dd HH:mm"))
    $apkPath = $apk.FullName
    $apkInstall = ('adb install -r "{0}"' -f $apk.FullName)
  }

  # PAS 4: Compact status report
  $statusText = @"
EXECUTION REPORT (COMPACT)
-------------------------
Status:   $status
Start:    $($start.ToString("HH:mm:ss"))
End:      $($end.ToString("HH:mm:ss"))
Duration: $(Format-Duration $dur)
Command:  $Command
Log:      $logPath
APK:      $apkSummary

Re-run:
  powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\run_compact.ps1" -Command "$Command" -TailLines $TailLines$(if ($Live) { " -Live" } else { "" })

Next:
  notepad "$logPath"
"@

  if ($apkPath) {
    $statusText += @"

  explorer "$([System.IO.Path]::GetDirectoryName($apkPath))"
  $apkInstall
"@
  }

  $statusTsPath = Join-Path $historyDir ("STATUS_{0}.txt" -f $ts)
  $statusText | Out-File -FilePath $latestStatusPath -Encoding UTF8
  $statusText | Out-File -FilePath $statusTsPath -Encoding UTF8

  # Also generate an HTML version with a real click-to-copy button.
  # NOTE: Cursor chat cannot run JS, but a local HTML file in a browser can.
  $latestHtmlPath = Join-Path $reportsDir "CHAT_STATUS_LATEST.html"
  $statusHtml = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>VaultGuard - CHAT_STATUS_LATEST</title>
  <style>
    body { background:#0f0f10; color:#fff; font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace; padding:16px; }
    .row { display:flex; gap:10px; align-items:center; margin-bottom:10px; flex-wrap:wrap; }
    button { background:#2b2b2e; color:#fff; border:1px solid #444; border-radius:6px; padding:8px 10px; cursor:pointer; }
    button:hover { background:#34343a; }
    .hint { color:#bdbdbd; font-size:12px; }
    pre { cursor:pointer; padding:12px; background:#1a1a1a; color:#fff; border:1px solid #444; border-radius:8px; white-space:pre-wrap; }
  </style>
</head>
<body>
  <div class="row">
    <button id="copyBtn" type="button">Copy report</button>
    <span class="hint">Tip: click anywhere inside the report to copy all</span>
  </div>
  <pre id="executionReport">$(Html-Encode $statusText)</pre>
  <script>
    (function () {
      var el = document.getElementById('executionReport');
      var btn = document.getElementById('copyBtn');
      function selectAll() {
        var range = document.createRange();
        range.selectNodeContents(el);
        var sel = window.getSelection();
        sel.removeAllRanges();
        sel.addRange(range);
      }
      function copyAll() {
        selectAll();
        var text = el.innerText || el.textContent || '';
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(text).catch(function () { document.execCommand('copy'); });
        } else {
          document.execCommand('copy');
        }
      }
      el.addEventListener('click', copyAll);
      btn.addEventListener('click', copyAll);
    })();
  </script>
</body>
</html>
"@
  $statusHtml | Out-File -FilePath $latestHtmlPath -Encoding UTF8

  Section "STATUS (LATEST)"
  if ($status -eq "SUCCESS") {
    Write-Host $statusText -ForegroundColor Green
  } else {
    Write-Host $statusText -ForegroundColor Red
  }

  Write-Host ("Saved latest status to: {0}" -f $latestStatusPath) -ForegroundColor DarkGray
  Write-Host ("Saved status snapshot to: {0}" -f $statusTsPath) -ForegroundColor DarkGray
  Write-Host ("Saved HTML click-to-copy report to: {0}" -f $latestHtmlPath) -ForegroundColor DarkGray
}

