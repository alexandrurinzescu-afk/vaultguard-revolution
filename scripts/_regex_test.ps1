$ErrorActionPreference = "Stop"

$roadmap = "C:\Users\pc\VaultGuardRevolution\VAULTGUARD_REVOLUTION_ROADMAP.md"
$raw = Get-Content -LiteralPath $roadmap -Raw

$sp = "1.1.1"
$pattern = "(?m)^-\\s*\\[( |~|!|x|X)\\]\\s+" + [regex]::Escape($sp) + "\\b"

Write-Host "PATTERN:"
Write-Host $pattern
Write-Host ""
Write-Host "MATCH:"
if ($raw -match $pattern) { Write-Host "YES" } else { Write-Host "NO" }

Write-Host ""
Write-Host "LINE (Select-String):"
Select-String -LiteralPath $roadmap -Pattern "1\\.1\\.1" -Context 0,0

