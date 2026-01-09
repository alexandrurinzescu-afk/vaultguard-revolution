param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectPath = "C:\Users\pc\AndroidStudioProjects\VaultGuard",

  [Parameter(Mandatory = $false)]
  [string]$BackupRoot = "C:\Backup\VaultGuard",

  [Parameter(Mandatory = $false)]
  [string]$Label = "AUTO",

  [Parameter(Mandatory = $false)]
  [switch]$IncludeBuildOutputs
)

# Automated backup (ZIP + manifest).
# ASCII-only script for Windows PowerShell 5.1 stability.

$ErrorActionPreference = "Stop"

function Ensure-Dir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) {
    New-Item -ItemType Directory -Force -Path $p | Out-Null
  }
}

if (-not (Test-Path -LiteralPath $ProjectPath)) {
  throw ("ProjectPath not found: {0}" -f $ProjectPath)
}

Ensure-Dir $BackupRoot

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $BackupRoot $timestamp
Ensure-Dir $backupDir

$zipName = ("VaultGuard_{0}_Backup_{1}.zip" -f $Label, $timestamp)
$backupFile = Join-Path $backupDir $zipName

$exclude = @()
if (-not $IncludeBuildOutputs) {
  $exclude += @("**\\build\\**","**\\.gradle\\**","**\\.idea\\**","**\\app\\build\\**")
}

# Compress-Archive has no exclude; so we stage a file list and copy to a temp dir.
$temp = Join-Path $env:TEMP ("vaultguard_backup_{0}" -f $timestamp)
if (Test-Path -LiteralPath $temp) { Remove-Item -Recurse -Force -LiteralPath $temp }
New-Item -ItemType Directory -Path $temp | Out-Null

robocopy $ProjectPath $temp /MIR /XD ".git" ".gradle" ".idea" "build" "app\\build" | Out-Null

Compress-Archive -Path (Join-Path $temp "*") -DestinationPath $backupFile -CompressionLevel Optimal

$sizeMB = [math]::Round((Get-Item -LiteralPath $backupFile).Length / 1MB, 2)
$manifest = Join-Path $backupDir "MANIFEST.txt"

@"
VAULTGUARD BACKUP MANIFEST
=========================
Time: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Project: $ProjectPath
Label: $Label
IncludeBuildOutputs: $IncludeBuildOutputs
BackupFile: $backupFile
SizeMB: $sizeMB

Top files (sample):
"@ | Out-File -FilePath $manifest -Encoding UTF8

Get-ChildItem -Path $ProjectPath -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Extension -in @(".kt",".java",".xml",".kts",".md",".ps1") } |
  Select-Object -First 120 |
  ForEach-Object { $_.FullName.Replace($ProjectPath, "") } |
  Out-File -FilePath $manifest -Append -Encoding UTF8

try { Remove-Item -Recurse -Force -LiteralPath $temp } catch { }

Write-Output ("Backup created: {0}" -f $backupFile)
Write-Output ("Size: {0} MB" -f $sizeMB)
Write-Output ("Manifest: {0}" -f $manifest)

