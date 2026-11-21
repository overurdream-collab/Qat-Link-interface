# Safe no-domain Tailscale Funnel test, using EXISTING FIN25 Caddy (127.0.0.1:8443).
# Defaults to read-only preflight. -Enable deliberately exposes the existing
# Caddy API publicly; never enables SMS public request or mutates Docker.
param([switch]$Enable,[switch]$Disable)
$ErrorActionPreference='Stop'
if($Enable -and $Disable){throw 'Choose either -Enable or -Disable'}
$cli=(Get-Command tailscale.exe -ErrorAction SilentlyContinue)
if(-not $cli){
 $fallback=Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
 if(Test-Path -LiteralPath $fallback){$exe=$fallback}else{
  throw 'TAILSCALE_NOT_INSTALLED: install desktop app from https://tailscale.com/download/windows and sign in'
 }
}else{$exe=$cli.Source}
function Check([string]$label){if($LASTEXITCODE -ne 0){throw "$label failed (exit $LASTEXITCODE)"}}
function Probe([string]$path,[string]$method='GET'){
 $a=@('-ksS','--max-time','10','-o','NUL','-w','%{http_code}','-X',$method)
 if($method -eq 'POST'){$a+=@('-H','content-type: application/json','--data','{}')}
 $result=(& curl.exe @a "https://127.0.0.1:8443$path"|Select-Object -Last 1)
 Check "Local Caddy $path"
 return [string]$result
}
if($Disable){
 & $exe funnel --https=443 off
 Check 'Disable Funnel port 443'
 Write-Host 'TAILSCALE_FUNNEL=OFF (Docker/Cloudflare unchanged)'
 exit 0
}
$statusRaw=(& $exe status --json|Out-String)
Check 'Tailscale status'
$status=$statusRaw|ConvertFrom-Json
if($status.BackendState -ne 'Running'){throw 'TAILSCALE_NOT_CONNECTED: sign in and connect Tailscale'}
$dns=[string]$status.Self.DNSName
if(-not $dns.EndsWith('.ts.net.')){throw 'NO_TAILSCALE_DNS: MagicDNS and HTTPS may need enabling in Tailscale admin'}
$origin='https://'+$dns.TrimEnd('.')
if((Probe '/healthz') -ne '200'){throw 'Local Identity health is not 200'}
if((Probe '/v1/identity/me') -ne '401'){throw 'Local unauthenticated identity /me must be 401'}
if((Probe '/v1/internal/otp/proof' 'POST') -ne '404'){throw 'Internal OTP proof exposed'}
if((Probe '/v1/auth/otp/request' 'POST') -ne '403'){throw 'Operator OTP route not blocked'}
if((Probe '/v1/auth/otp/public-request' 'POST') -ne '503'){throw 'Public SMS is not disabled; refusing public exposure'}
$existing=(& $exe funnel status --json 2>$null|Out-String)
if($LASTEXITCODE -ne 0){$existing=''}
if($existing -match '"443"' -or $existing -match '"Funnel"'){
 throw 'EXISTING_FUNNEL_CONFIGURATION: review Tailscale funnel status before overwriting'
}
Write-Host 'LOCAL_FIN25=PASS (5/5; SMS public request disabled)'
Write-Host "PUBLIC_ORIGIN=$origin"
if(-not $Enable){
 Write-Host 'PREFLIGHT=PASS; no Funnel or Docker change made'
 Write-Host 'Use -Enable only when ready to expose existing Caddy routes to the public internet.'
 exit 0
}
Write-Host 'Enabling port 443 Funnel to existing localhost HTTPS Caddy (self-signed origin; outer public TLS trusted).'
# Tailscale can ask user to approve MagicDNS/HTTPS/Funnel in browser. This is expected.
& $exe funnel --bg --https=443 'https+insecure://127.0.0.1:8443'
Check 'Enable Funnel'
Write-Host "FUNNEL_CONFIGURED=$origin"
Write-Host 'Public tests must use standard TLS verification (NO -k).'
Write-Host "RUN_NEXT: powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\check_unified_auth_public_https.ps1 -Origin $origin"
Write-Host 'If tests fail or exposure is unwanted, run this script with -Disable. No Docker rollback is necessary.'
