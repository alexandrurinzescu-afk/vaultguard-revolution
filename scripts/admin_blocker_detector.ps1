param()

# Admin blocker detector (PowerShell 5.1 friendly)
# - Pattern-based detection for commands that likely require admin privileges.
# - Helper to check if the current process is elevated.

function Test-IsAdmin {
  try {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  } catch {
    return $false
  }
}

function Test-AdminRequirement {
  param(
    [Parameter(Mandatory = $true)][string]$CommandText
  )

  $adminPatterns = @(
    "HKLM:\\",
    "HKEY_LOCAL_MACHINE",
    "LocalMachine",
    "Set-ItemProperty HKLM",
    "Set-PageFile",
    "Win32_PageFile",
    "Win32_ComputerSystem",
    "EnableAllPrivileges",
    "Set-WmiInstance",
    "Get-WmiObject",
    "wmic pagefileset",
    "schtasks",
    "New-Service",
    "sc.exe",
    "netsh advfirewall",
    "Restart-Computer -Force",
    "bcdedit",
    "powercfg /setactive"
  )

  foreach ($p in $adminPatterns) {
    if ($CommandText -match [regex]::Escape($p)) { return $true }
  }

  return $false
}

