# Read-only existing FIN25 Caddy / Identity / OTP / FIN08 preflight.
# Does NOT deploy, recreate, stop, migrate DB or send any SMS.
$ErrorActionPreference='Stop'
$required=@('fin25-test-db','fin25-test-otp-1','fin25-test-https-1',
 'maqwati-identity-p0-identity-1','maqwatilink-api-1')
$names=@(docker ps --format '{{.Names}}')
if($LASTEXITCODE -ne 0){throw 'Docker inventory failed'}
foreach($container in $required){
 if($names -contains $container){Write-Host "$container=RUNNING"}
 else{Write-Host "$container=NOT_RUNNING"}
}
function Get-HttpStatus([string]$url,[string]$method='GET'){
 # -k is ONLY for localhost against the known self-signed origin certificate.
 # Android must NEVER bypass TLS validation.
 $out=(& curl.exe -sS -k -o NUL -w '%{http_code}' --max-time 10 -X $method -H 'content-type: application/json' --data '{}' $url 2>$null)
 if($LASTEXITCODE -ne 0){return 'UNREACHABLE'}
 return ($out | Select-Object -Last 1).Trim()
}
$base='https://localhost:8443'
$health=Get-HttpStatus "$base/healthz" 'GET'
$me=Get-HttpStatus "$base/v1/identity/me" 'GET'
$internal=Get-HttpStatus "$base/v1/internal/otp/proof" 'POST'
$public=Get-HttpStatus "$base/v1/auth/otp/public-request" 'POST'
Write-Host "HEALTH=$health IDENTITY_ME=$me PRIVATE_PROOF=$internal PUBLIC_OTP_EMPTY_BODY=$public"
if($health -eq '200' -and $me -eq '401' -and $internal -eq '404' -and @('503','400') -contains $public){
 Write-Host 'UNIFIED_ROUTING=PASS (this does NOT prove DNS/WAF or actual login)'
}else{
 Write-Host 'UNIFIED_ROUTING=BLOCKED (gateway not deployed or service unavailable)'
}
Write-Host 'No service, certificate, database, or financial data was changed.'
