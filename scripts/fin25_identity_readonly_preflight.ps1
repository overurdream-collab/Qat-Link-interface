# Read-only FIN25 test-environment readiness inventory.
# Never prints credentials or modifies Docker, device state, SMS queues, or DB.
[CmdletBinding()]
param([string]$OutputPath = "")
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Capture([string]$Command, [scriptblock]$Body) {
  try { & $Body } catch { Write-Host "[WARN] $Command : $($_.Exception.Message)" }
}
$rows = @()
Capture 'Docker listing' {
  $jsonLines = & docker ps -a --format '{{json .}}'
  if ($LASTEXITCODE -ne 0) { throw 'Docker read-only listing failed' }
  $rows = @($jsonLines | Where-Object { $_ } | ForEach-Object { $_ | ConvertFrom-Json } |
    Where-Object { $_.Names -match '^fin25-test-' } |
    Select-Object Names,Image,Status,Ports)
  Write-Host "[INFO] fin25-test containers: $($rows.Count)"
  $rows | Format-Table -AutoSize | Out-String | Write-Host
}
Capture 'Running tunnel hostname from logs' {
  $log = & docker logs fin25-test-tunnel --tail 100 2>&1
  if ($LASTEXITCODE -ne 0) { throw 'Tunnel log unavailable' }
  $hosts = [regex]::Matches(($log -join "`n"),'https://[a-z0-9-]+[.]trycloudflare[.]com') |
    ForEach-Object { $_.Value } | Select-Object -Unique
  Write-Host "[INFO] Tunnel addresses seen in recent log (historical, verify on device):"
  $hosts | ForEach-Object { Write-Host $_ }
}
Capture 'OTP environment variable presence only' {
  $args = @(
    'exec','fin25-test-otp-1','node','-e',
    'for(const k of ["OTP_ENABLED","FIN25_SMS_DISPATCH_ENABLED","JWT_PUBLIC_KEY_PEM","JWT_ISSUER","JWT_AUDIENCE","OTP_INTERNAL_API_KEY"]){const v=process.env[k];console.log(k+"="+(v===undefined?"ABSENT":"PRESENT"))}'
  )
  & docker @args
  if ($LASTEXITCODE -ne 0) { throw 'OTP container not available' }
}
Capture 'Application readiness files' {
  $paths = @(
    'server/src/identity_logic.mjs',
    'server/src/identity_server.mjs',
    'server/src/identity_finance_provisioner.mjs',
    'server/sql/008_p0_identity_accounts.sql',
    'docs/P0_IDENTITY_DEPLOYMENT_HANDOVER_AR.md'
  )
  $repo = Split-Path -Parent $PSScriptRoot
  foreach($p in $paths) {
    $exists = Test-Path -LiteralPath (Join-Path $repo $p)
    Write-Host ("[FILE] {0}: {1}" -f $p, $(if ($exists) {'PRESENT'} else {'MISSING'}))
  }
}
Write-Host "[RESULT] Read-only inspection complete. Nothing was sent, restarted, approved or deployed."
Write-Host "[NEXT] Compare container source versions, plan isolated identity DB and trusted HTTPS endpoint before any deployment."
