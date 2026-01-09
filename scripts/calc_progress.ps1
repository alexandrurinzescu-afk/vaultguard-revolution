$ErrorActionPreference = "Stop"

$roadmapPath = "C:\Users\pc\VaultGuardRevolution\VAULTGUARD_REVOLUTION_ROADMAP.md"
$r = Get-Content -LiteralPath $roadmapPath -Raw

$total = ([regex]::Matches($r, "\d+\.\d+\.\d+")).Count
$completed = ([regex]::Matches($r, "(?m)^- \[[xX]\]")).Count
$remaining = $total - $completed

Write-Host ("TOTAL={0}" -f $total)
Write-Host ("COMPLETED={0}" -f $completed)
Write-Host ("REMAINING={0}" -f $remaining)

