# VaultGuard Revolution - Monitoring Common Utilities
# PowerShell 5.1 friendly. ASCII-only output (no emoji).

$ErrorActionPreference = "Stop"

function Ensure-Directory {
  param([Parameter(Mandatory=$true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
  }
}

function Get-MonitoringRoot {
  # Deployed location
  return "C:\VAULTGUARD_UNIVERSE\MONITORING"
}

function Get-RepoRoot {
  # If running from repo: <repo>/monitoring/*.ps1
  return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Get-ProjectRoot {
  return "C:\Users\pc\VaultGuardRevolution"
}

function Get-RoadmapPath {
  return (Join-Path (Get-ProjectRoot) "VAULTGUARD_REVOLUTION_ROADMAP.md")
}

function Write-LogLine {
  param(
    [Parameter(Mandatory=$true)][string]$LogPath,
    [Parameter(Mandatory=$true)][string]$Level,
    [Parameter(Mandatory=$true)][string]$Message
  )
  $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $line = "[{0}] [{1}] {2}" -f $ts, $Level.ToUpperInvariant(), $Message
  Add-Content -LiteralPath $LogPath -Value ($line + "`r`n") -Encoding UTF8
}

function Test-StopFlag {
  $root = Get-MonitoringRoot
  return (Test-Path -LiteralPath (Join-Path $root "STOP_ALL.flag"))
}

function Find-CursorExe {
  $candidates = @(
    "C:\Program Files\Cursor\Cursor.exe",
    "C:\Program Files (x86)\Cursor\Cursor.exe",
    (Join-Path $env:LOCALAPPDATA "Programs\Cursor\Cursor.exe")
  )
  foreach ($p in $candidates) {
    if (Test-Path -LiteralPath $p) { return $p }
  }
  return $null
}

function Test-CursorRunning {
  return [bool](Get-Process -Name "Cursor" -ErrorAction SilentlyContinue)
}

function Restart-CursorBestEffort {
  param([string]$LogPath)
  try {
    Get-Process -Name "Cursor" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
  } catch { }

  $exe = Find-CursorExe
  if ($exe) {
    Start-Process -FilePath $exe | Out-Null
    if ($LogPath) { Write-LogLine -LogPath $LogPath -Level "INFO" -Message ("Started Cursor: {0}" -f $exe) }
    return $true
  }

  if ($LogPath) { Write-LogLine -LogPath $LogPath -Level "WARN" -Message "Cursor.exe not found in common locations." }
  return $false
}

function Get-SystemLoad {
  $cpu = $null
  $mem = $null
  try {
    $cpu = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
  } catch { $cpu = $null }
  try {
    $mem = Get-CimInstance Win32_OperatingSystem | ForEach-Object {
      [math]::Round(($_.TotalVisibleMemorySize - $_.FreePhysicalMemory) / $_.TotalVisibleMemorySize * 100, 2)
    }
  } catch { $mem = $null }
  return @{ CPU = $cpu; Memory = $mem }
}

function Test-Internet {
  try {
    return [bool](Test-NetConnection -ComputerName "8.8.8.8" -InformationLevel Quiet -ErrorAction SilentlyContinue)
  } catch {
    return $false
  }
}

function Test-AdbConnected {
  if (-not (Get-Command adb -ErrorAction SilentlyContinue)) { return $null }
  try {
    $out = (adb devices 2>$null)
    return [bool]($out -match "device$")
  } catch {
    return $false
  }
}

function Restart-AdbBestEffort {
  if (-not (Get-Command adb -ErrorAction SilentlyContinue)) { return $false }
  try {
    adb kill-server | Out-Null
    Start-Sleep -Seconds 2
    adb start-server | Out-Null
    Start-Sleep -Seconds 2
    return $true
  } catch {
    return $false
  }
}

function Invoke-DesktopToolBestEffort {
  param(
    [Parameter(Mandatory=$true)][ValidateSet("CursorCheck","CursorFixer","CursorStatus")]
    [string]$Tool,
    [string]$LogPath
  )

  $desktop = Join-Path $env:USERPROFILE "Desktop"
  $candidates = @()
  switch ($Tool) {
    "CursorCheck"  { $candidates = @("CursorCheck.ps1","CursorStatus.ps1","CursorStatus_Fixed.ps1") }
    "CursorFixer"  { $candidates = @("CursorFixer_Control.ps1") }
    "CursorStatus" { $candidates = @("CursorStatus_Fixed.ps1","CursorStatus.ps1") }
  }

  foreach ($name in $candidates) {
    $p = Join-Path $desktop $name
    if (Test-Path -LiteralPath $p) {
      Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-File",$p) -WindowStyle Hidden | Out-Null
      if ($LogPath) { Write-LogLine -LogPath $LogPath -Level "INFO" -Message ("Launched desktop tool: {0}" -f $p) }
      return $true
    }
  }

  if ($LogPath) { Write-LogLine -LogPath $LogPath -Level "WARN" -Message ("Desktop tool not found: {0}" -f $Tool) }
  return $false
}

function Get-RoadmapText {
  $path = Get-RoadmapPath
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  return (Get-Content -LiteralPath $path -Raw -ErrorAction Stop)
}

function Get-OrderedSubpointsFromRoadmap {
  param([Parameter(Mandatory=$true)][string]$RoadmapText)
  $matches = [regex]::Matches($RoadmapText, "(?m)^- \[[ xX!~]\]\s+(\d+\.\d+\.\d+)\b")
  $list = @()
  foreach ($m in $matches) { $list += $m.Groups[1].Value }
  return $list
}

function Get-SubpointStateMap {
  param([Parameter(Mandatory=$true)][string]$RoadmapText)
  $matches = [regex]::Matches($RoadmapText, "(?m)^- \[([ xX!~])\]\s+(\d+\.\d+\.\d+)\b")
  $map = @{}
  foreach ($m in $matches) {
    $map[$m.Groups[2].Value] = $m.Groups[1].Value
  }
  return $map
}

function Get-ProgressStats {
  $text = Get-RoadmapText
  if (-not $text) { return $null }
  $completed = ([regex]::Matches($text, "(?m)^- \[[xX]\]")).Count
  $total = ([regex]::Matches($text, "\d+\.\d+\.\d+")).Count
  $remaining = $total - $completed
  $pct = if ($total -gt 0) { [math]::Round(($completed / $total) * 100, 2) } else { 0 }
  return @{ Completed = $completed; Total = $total; Remaining = $remaining; Percent = $pct }
}

function Get-NextIncompleteSubpoints {
  param([int]$Count = 3)
  $text = Get-RoadmapText
  if (-not $text) { return @() }
  $ordered = Get-OrderedSubpointsFromRoadmap -RoadmapText $text
  $state = Get-SubpointStateMap -RoadmapText $text
  $pending = @()
  foreach ($id in $ordered) {
    if ($state.ContainsKey($id) -and $state[$id] -match "^[ ]$") {
      $pending += $id
      if ($pending.Count -ge $Count) { break }
    }
  }
  return $pending
}

function Try-TakeScreenshot {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [string]$LogPath
  )
  try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bmp)
    $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bmp.Dispose()
    if ($LogPath) { Write-LogLine -LogPath $LogPath -Level "INFO" -Message ("Screenshot saved: {0}" -f $Path) }
    return $true
  } catch {
    if ($LogPath) { Write-LogLine -LogPath $LogPath -Level "WARN" -Message ("Screenshot failed: {0}" -f $_.Exception.Message) }
    return $false
  }
}

