param(
  [Parameter(Mandatory = $false)]
  [string[]]$CandidateIps = @("192.168.43.1","192.168.175.1","192.168.0.1"),

  [Parameter(Mandatory = $false)]
  [int]$TcpPort = 10010,

  [Parameter(Mandatory = $false)]
  [int]$HttpPort = 9000
)

$ErrorActionPreference = "Continue"

Write-Output ("Time: {0}" -f (Get-Date -Format "HH:mm:ss"))
Write-Output "X05 connectivity probe (ping + ports)"
Write-Output ("TCP port: {0} | HTTP port: {1}" -f $TcpPort, $HttpPort)
Write-Output ""

foreach ($ip in $CandidateIps) {
  Write-Output ("=== {0} ===" -f $ip)

  $pingOk = Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue
  Write-Output ("PING: {0}" -f ($(if ($pingOk) { "OK" } else { "FAIL" })))

  $tcp = Test-NetConnection -ComputerName $ip -Port $TcpPort -WarningAction SilentlyContinue
  Write-Output ("TCP {0}: {1}" -f $TcpPort, ($(if ($tcp.TcpTestSucceeded) { "OPEN" } else { "CLOSED" })))

  $http = Test-NetConnection -ComputerName $ip -Port $HttpPort -WarningAction SilentlyContinue
  Write-Output ("TCP {0}: {1}" -f $HttpPort, ($(if ($http.TcpTestSucceeded) { "OPEN" } else { "CLOSED" })))

  Write-Output ""
}

