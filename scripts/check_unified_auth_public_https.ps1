# Read-only externally trusted TLS/HTTP checks for a stable Maqwati hostname.
# Does NOT use -k, send SMS, deploy Docker, or reveal private credentials.
param([Parameter(Mandatory=$true)][string]$Origin,[switch]$AllowBetaPublicOtp)
$ErrorActionPreference='Stop'
if($Origin -notmatch '^https://'){throw 'HTTPS_ORIGIN_REQUIRED'}
try{$uri=[Uri]::new($Origin)}catch{throw 'INVALID_HTTPS_ORIGIN'}
$hostName=$uri.DnsSafeHost.ToLowerInvariant()
if($uri.Scheme -ne 'https' -or $uri.UserInfo -or $uri.AbsolutePath -ne '/' -or
   $uri.Query -or $uri.Fragment -or $uri.Port -ne 443 -or
   $hostName -in @('localhost','::1','127.0.0.1') -or
   $hostName.EndsWith('.trycloudflare.com') -or
   $hostName.EndsWith('.localhost') -or
   $hostName.StartsWith('127.') -or
   $hostName.StartsWith('10.') -or
   $hostName.StartsWith('192.168.') -or
   $hostName.EndsWith('.local')){
 throw 'BLOCKED: use a stable, publicly trusted HTTPS hostname, not localhost, private IP or a Quick Tunnel'
}
$tests=@(
 @{Path='/healthz';Method='GET';Expected='200'},
 @{Path='/v1/identity/me';Method='GET';Expected='401'},
 @{Path='/v1/internal/otp/proof';Method='POST';Expected='404'},
 @{Path='/v1/auth/otp/request';Method='POST';Expected='403'},
 @{Path='/v1/auth/otp/public-request';Method='POST';Expected=$(if($AllowBetaPublicOtp){'400'}else{'503'})}
)
$allPassed=$true
foreach($t in $tests){
 $url=$uri.GetLeftPart([System.UriPartial]::Authority)+$t.Path
 # No redirects, no insecure TLS, no SMS requests with a valid phone.
 $result=& curl.exe --silent --show-error --max-time 15 --max-redirs 0 -o NUL -w '%{http_code}' -X $t.Method -H 'content-type: application/json' --data '{}' $url
 $curlExit=$LASTEXITCODE
 $status=($result|Select-Object -Last 1)
 if($curlExit -ne 0){$status="TLS_OR_NETWORK_ERROR_$curlExit"}
 $pass=($status -eq $t.Expected)
 if(-not $pass){$allPassed=$false}
 $state=if($pass){'PASS'}else{'FAIL'}
 Write-Host "$state $($t.Path) HTTP=$status EXPECTED=$($t.Expected)"
}
if($allPassed){Write-Host 'EXTERNAL_HTTPS_ROUTING=PASS (WAF and real SMS still NOT proven)'}
else{Write-Host 'EXTERNAL_HTTPS_ROUTING=BLOCKED (do not enable public SMS)';exit 1}
