<#
VaultGuard PowerShell Auto-Report (Windows PowerShell 5.1 safe)
- Defines Invoke-WithReport + aliases: ir / run / exec
- Runs a command via Invoke-Expression
- Prints a compact execution report at the end

Key goal: emoji output WITHOUT relying on file encoding/BOM.
We generate emoji at runtime using Unicode code points / surrogate pairs.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Set this to $true (e.g. in $PROFILE) to enable emoji labels in the report.
if (-not (Get-Variable -Name VG_AUTO_REPORT_EMOJI -Scope Global -ErrorAction SilentlyContinue)) {
  $global:VG_AUTO_REPORT_EMOJI = $false
}

function Get-Emoji {
  param([Parameter(Mandatory = $true)][ValidateSet("clipboard","check","time","hourglass","chart","rerun","rocket")] [string]$Name)

  switch ($Name) {
    "clipboard" { return ([char]0xD83D + [char]0xDCCB) } # 📋 U+1F4CB
    "check"     { return ([char]0x2705) }               # ✅ U+2705
    "time"      { return ([char]0x23F1) }               # ⏱ U+23F1
    "hourglass" { return ([char]0x23F3) }               # ⏳ U+23F3
    "chart"     { return ([char]0xD83D + [char]0xDCCA) } # 📊 U+1F4CA
    "rerun"     { return ([char]0xD83D + [char]0xDD04) } # 🔄 U+1F504
    "rocket"    { return ([char]0xD83D + [char]0xDE80) } # 🚀 U+1F680
  }
}

function Get-NextStepSuggestion {
  param([Parameter(Mandatory = $true)][string]$Command)

  $c = $Command.ToLowerInvariant()

  if ($c -match "gradlew(\.bat)?\s+assembledebug") {
    return 'adb install -r "app\build\outputs\apk\debug\app-debug.apk"'
  }
  if ($c -match "git\s+add(\s|$)") {
    return "git commit -m 'Your message'"
  }
  if ($c -match "npm\s+install(\s|$)") {
    return "npm start"
  }
  if ($c -match "adb\s+devices(\s|$)") {
    return "adb install -r <apk_path>"
  }

  return "Review output/logs; run next logical step."
}

function Invoke-WithReport {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Command
  )

  # Help PS 5.1 terminals display Unicode when possible.
  try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

  $start = Get-Date
  $output = $null
  $status = "UNKNOWN"
  $exitCode = $null
  $threw = $false

  try {
    # Reset LASTEXITCODE so cmdlets don't inherit a previous native command exit.
    $global:LASTEXITCODE = 0

    # Run and capture stdout+stderr.
    # Note: Invoke-Expression does not stream output live.
    $output = Invoke-Expression $Command 2>&1

    $exitCode = $global:LASTEXITCODE
    if ($exitCode -eq $null) { $exitCode = 0 }

    if ($exitCode -eq 0) { $status = "SUCCESS" }
    else { $status = "FAILED (exit $exitCode)" }
  }
  catch {
    $threw = $true
    $status = "FAILED (exception)"
  }
  finally {
    $end = Get-Date
    $dur = New-TimeSpan -Start $start -End $end
    $durSec = [math]::Round($dur.TotalSeconds, 3)
    $timeStr = $end.ToString("HH:mm:ss")
    $next = Get-NextStepSuggestion -Command $Command

    # Print command output first (so the report stays at the bottom)
    if ($output -ne $null) { $output | ForEach-Object { Write-Output $_ } }

    $useEmoji = [bool]$global:VG_AUTO_REPORT_EMOJI

    $h = "EXECUTION REPORT (click to copy)"
    $lStatus = "Status:"
    $lTime = "Time:"
    $lDur = "Duration:"
    $lCmd = "Command:"
    $lRerun = "Re-run:"
    $lNext = "Next:"

    if ($useEmoji) {
      $h = ("{0} EXECUTION REPORT (Click pentru copy)" -f (Get-Emoji clipboard))
      $lStatus = ("{0} Status:" -f (Get-Emoji check))
      $lTime = ("{0} Time:" -f (Get-Emoji time))
      $lDur = ("{0} Duration:" -f (Get-Emoji hourglass))
      $lCmd = ("{0} Command:" -f (Get-Emoji chart))
      $lRerun = ("{0} Re-run:" -f (Get-Emoji rerun))
      $lNext = ("{0} Next:" -f (Get-Emoji rocket))
    }

    Write-Host ""
    Write-Host $h -ForegroundColor Green
    Write-Host ("{0} {1}" -f $lStatus, $status) -ForegroundColor Green
    Write-Host ("{0} {1}" -f $lTime, $timeStr) -ForegroundColor Cyan
    Write-Host ("{0} {1}s" -f $lDur, $durSec) -ForegroundColor Cyan
    Write-Host ("{0} {1}" -f $lCmd, $Command) -ForegroundColor White
    Write-Host ("{0} {1}" -f $lRerun, $Command) -ForegroundColor Yellow
    Write-Host ("{0} {1}" -f $lNext, $next) -ForegroundColor Magenta
    Write-Host "---" -ForegroundColor DarkGray

    # Preserve conventional PowerShell success semantics for callers.
    if ($threw -or ($exitCode -ne $null -and $exitCode -ne 0)) {
      $global:LASTEXITCODE = [int]$exitCode
    } else {
      $global:LASTEXITCODE = 0
    }
  }
}

Set-Alias -Name ir -Value Invoke-WithReport -Scope Global
Set-Alias -Name run -Value Invoke-WithReport -Scope Global
Set-Alias -Name exec -Value Invoke-WithReport -Scope Global

