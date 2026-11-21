# Read-only deployment gap assessment for FIN08 account overview.
# Never prints credentials, phone numbers, JWT, environment values or response bodies.
$ErrorActionPreference='Stop'
function Check([string]$step){if($LASTEXITCODE -ne 0){throw "$step failed"}}
$identity='maqwati-identity-p0-identity-1'
$caddy='fin25-test-https-1'
$fin08='maqwatilink-api-1'
foreach($name in @($identity,$caddy,$fin08)){
 $s=(& docker inspect --format '{{.State.Status}}' $name|Select-Object -Last 1).Trim()
 Check "Inspect $name"
 Write-Host "$name=$s"
 if($s -ne 'running'){throw "$name is not running"}
}
# This checks actual existing private FIN08 reachability from already-networked Identity.
& docker exec $identity node --input-type=module -e 'const o=process.env.FIN08_INTERNAL_BASE_URL;if(!o)process.exit(5);try{const r=await fetch(new URL("/healthz",o),{signal:AbortSignal.timeout(5000)});console.log("IDENTITY_TO_FIN08_HEALTH_HTTP="+r.status);if(r.status!==200)process.exitCode=6}catch{console.log("IDENTITY_TO_FIN08=UNREACHABLE");process.exitCode=7}'
Check 'Existing Identity-to-FIN08 private network'
& docker exec $identity sh -c 'test -f /app/src/identity_fin08_read_proxy.mjs'
if($LASTEXITCODE -eq 0){Write-Host 'FIN08_READ_PROXY_IN_LIVE_IDENTITY=PRESENT'}else{Write-Host 'FIN08_READ_PROXY_IN_LIVE_IDENTITY=NOT_DEPLOYED'}
$routes=@(
 '/v1/merchant/contacts',
 '/v1/merchant/claims/summary',
 '/v1/customer/relationships',
 '/v1/customer/previous-claims'
)
foreach($route in $routes){
 $r=& curl.exe -ksS --max-time 10 -o NUL -w '%{http_code}' "https://localhost:8443$route"
 Check "Caddy route test $route"
 Write-Host "UNAUTHENTICATED_GET $route HTTP=$($r|Select-Object -Last 1)"
}
Write-Host 'FIN08_PRECHECK=PASS (READ_ONLY; no live service changed)'
