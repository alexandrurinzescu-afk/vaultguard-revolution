param(
  [Parameter(Mandatory = $false)]
  [switch]$AsciiOnly
)

# Status report template helpers.
# Note: Emoji may render differently across terminals; use -AsciiOnly for safe logs.

function Get-StatusTemplate {
  param([switch]$AsciiOnly)

  if ($AsciiOnly) {
    return @'
EXECUTION REPORT
Status: {STATUS}
Time: {TIME}
Summary: {SUMMARY}
Re-run: {RERUN}
Next: {NEXT}
---
'@
  }

  return @'
📋 EXECUTION REPORT (Click pentru copy)
✅ Status: {STATUS}
⏱ Time: {TIME}
📊 Summary: {SUMMARY}
🔄 Re-run: {RERUN}
🚀 Next: {NEXT}
---
'@
}

function Format-ExecutionReport {
  param(
    [Parameter(Mandatory = $true)][string]$Status,
    [Parameter(Mandatory = $true)][string]$Time,
    [Parameter(Mandatory = $true)][string]$Summary,
    [Parameter(Mandatory = $true)][string]$Rerun,
    [Parameter(Mandatory = $true)][string]$Next,
    [Parameter(Mandatory = $false)][switch]$AsciiOnly
  )

  $t = Get-StatusTemplate -AsciiOnly:$AsciiOnly
  # Use literal string replacement (NOT regex) to avoid inserting backslashes
  # (Regex.Escape would corrupt natural text like "git status" -> "git\ status").
  return $t.Replace("{STATUS}", $Status).
    Replace("{TIME}", $Time).
    Replace("{SUMMARY}", $Summary).
    Replace("{RERUN}", $Rerun).
    Replace("{NEXT}", $Next)
}

# Convenience: print template to stdout when called directly.
$statusTemplate = Get-StatusTemplate -AsciiOnly:$AsciiOnly
Write-Output $statusTemplate

