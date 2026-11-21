# Public beta OTP request gate for an existing FIN25 stack. No DB/keys changes.
# Default = dry-run; -Enable exposes to all Internet callers (not just APK owners).
# -Disable restores original OTP environment and original new-image overlay.
param([switch]$Enable,[switch]$Disable,[ValidateRange(1,12)][int]$HourlyBudget=6)
$ErrorActionPreference='Stop'
if($Enable -and $Disable){throw 'Select -Enable or -Disable, not both'}
$live='F:\maqwatilink-fin25\deploy\fin25'
$base=Join-Path $live 'docker-compose.yml'
$preserve='F:\maqwatilink-secrets\identity-recovery-20261120\preserve-live.override.json'
$promotion=Join-Path $live 'otp-unified-promotion.override.yml'
$envFile=Join-Path $live '.env'
$beta=Join-Path $live 'otp-public-beta.override.yml'
$container='fin25-test-otp-1'
$expectedImage='sha256:310d4573e701066e6bc0c95ceefe3cac4fa5d5e2d11b889715d175b3e705797c'
function Check([string]$msg){if($LASTEXITCODE -ne 0){throw "$msg failed (exit $LASTEXITCODE)"}}
function Probe([string]$path,[string]$method='POST') {
 $r=& curl.exe -ksS --max-time 10 -o NUL -w '%{http_code}' -X $method -H 'content-type: application/json' --data '{}' "https://localhost:8443$path"
 Check "HTTP $path"
 return ($r|Select-Object -Last 1).Trim()
}
foreach($file in @($base,$preserve,$promotion,$envFile)){
 if(-not(Test-Path -LiteralPath $file -PathType Leaf)){throw "Missing required live file: $file"}
}
$orig=@('--project-directory',$live,'-p','fin25-test','-f',$base,'-f',$preserve,'-f',$promotion,'--env-file',$envFile)
$current=@(docker inspect $container|ConvertFrom-Json);Check 'OTP inspect'
if($current.Count -ne 1 -or -not $current[0].State.Running -or $current[0].Image -ne $expectedImage){
 throw 'Current OTP container does not match verified live image; refusing update'
}
$baseRaw=(& docker compose @orig config --format json|Out-String);Check 'Known Compose config'
$baseConfig=$baseRaw|ConvertFrom-Json
if($baseConfig.services.otp.image -ne $expectedImage){throw 'Promotion overlay does not pin verified OTP image'}
if([string]$baseConfig.services.otp.environment.OTP_PUBLIC_REQUEST_ENABLED -eq 'true'){
 throw 'Original OTP configuration is already publicly enabled; review before toggling'
}
if([string]$baseConfig.services.otp.environment.OTP_ENABLED -ne 'true'){
 throw 'OTP_ENABLED not true; do not expose a non-working beta'
}
if([string]$baseConfig.services.otp.environment.FIN25_SMS_DISPATCH_ENABLED -ne 'true'){
 throw 'FIN25_SMS_DISPATCH_ENABLED not true; gateway cannot deliver SMS'
}
if($Disable){
 if(-not(Test-Path -LiteralPath $beta)){
   Write-Host 'PUBLIC_OTP=ALREADY_CONFIGURED_DISABLED; no running container changed'
   exit 0
 }
 # Roll back ONLY the OTP container to config without beta override.
 docker compose @orig up -d --no-deps --no-build --force-recreate otp
 Check 'Disable public beta OTP'
 $actual=Probe '/v1/auth/otp/public-request'
 if($actual -ne '503'){throw "Public SMS shutdown NOT confirmed HTTP=$actual; manual attention required"}
 $now=(& docker inspect --format '{{.Image}}' $container|Select-Object -Last 1).Trim();Check 'OTP image after disable'
 if($now -ne $expectedImage){throw 'Wrong OTP image after disable'}
 Remove-Item -LiteralPath $beta -Force
 Write-Host 'PUBLIC_OTP=DISABLED HTTP=503'
 exit 0
}
if(Test-Path -LiteralPath $beta){throw "Existing beta config requires review; refusing overwrite: $beta"}
# Compose overlay contains no credentials. Budget caps TOTAL requests across all phones.
$yaml=@"
services:
  otp:
    environment:
      OTP_PUBLIC_REQUEST_ENABLED: "true"
      OTP_PUBLIC_MAX_PER_HOUR: "$HourlyBudget"
"@
$wrote=$false
$keep=$false
try{
 [System.IO.File]::WriteAllText($beta,$yaml,([System.Text.UTF8Encoding]::new($false)))
 $wrote=$true
 $candidate=@('--project-directory',$live,'-p','fin25-test','-f',$base,'-f',$preserve,'-f',$promotion,'-f',$beta,'--env-file',$envFile)
 $newRaw=(& docker compose @candidate config --format json|Out-String);Check 'Beta Compose config'
 $newConfig=$newRaw|ConvertFrom-Json
 foreach($service in @('enrollment','https')){
  if(($baseConfig.services.$service|ConvertTo-Json -Compress -Depth 30) -cne
    ($newConfig.services.$service|ConvertTo-Json -Compress -Depth 30)){
    throw "Unrelated service $service changed"
  }
 }
 $b=$baseConfig.services.otp.PSObject.Copy();$n=$newConfig.services.otp.PSObject.Copy()
 $b.PSObject.Properties.Remove('environment');$n.PSObject.Properties.Remove('environment')
 if(($b|ConvertTo-Json -Compress -Depth 30) -cne ($n|ConvertTo-Json -Compress -Depth 30)){
  throw 'OTP properties outside environment changed'
 }
 foreach($k in $baseConfig.services.otp.environment.PSObject.Properties.Name){
  if($k -in @('OTP_PUBLIC_REQUEST_ENABLED','OTP_PUBLIC_MAX_PER_HOUR')){continue}
  if([string]$baseConfig.services.otp.environment.$k -cne [string]$newConfig.services.otp.environment.$k){
   throw "OTP environment changed unexpectedly: $k"
  }
 }
 if($newConfig.services.otp.image -ne $expectedImage -or
  [string]$newConfig.services.otp.environment.OTP_PUBLIC_REQUEST_ENABLED -ne 'true' -or
  [string]$newConfig.services.otp.environment.OTP_PUBLIC_MAX_PER_HOUR -ne [string]$HourlyBudget){
  throw 'Public beta configuration mismatch'
 }
 if((Probe '/healthz' 'GET') -ne '200' -or
    (Probe '/v1/internal/otp/proof') -ne '404' -or
    (Probe '/v1/auth/otp/request') -ne '403'){
  throw 'Existing security routing failed'
 }
 Write-Host "OTP_BETA_PREFLIGHT=PASS HOURLY_GLOBAL_BUDGET=$HourlyBudget"
 Write-Host 'WARNING: Public endpoint is reachable by anyone on the Internet, not only beta APK testers.'
 if(-not $Enable){Write-Host 'DRY_RUN=PASS; no running container changed';exit 0}
 $changed=$false
 try{
  docker compose @candidate up -d --no-deps --no-build --force-recreate otp
  Check 'Enable beta OTP container'
  $changed=$true
  $image=(& docker inspect --format '{{.Image}}' $container|Select-Object -Last 1).Trim();Check 'OTP image'
  if($image -ne $expectedImage){throw 'OTP image changed'}
  if((Probe '/healthz' 'GET') -ne '200'){throw 'Identity health regression'}
  if((Probe '/v1/internal/otp/proof') -ne '404'){throw 'Proof route exposed'}
  if((Probe '/v1/auth/otp/request') -ne '403'){throw 'Operator route exposed'}
  # Empty JSON has no phone; 400 proves open handler WITHOUT queuing SMS.
  $public=Probe '/v1/auth/otp/public-request'
  if($public -ne '400'){throw "Expected HTTP 400 without a phone, got $public"}
  $keep=$true
  Write-Host "PUBLIC_OTP=BETA_ENABLED HTTP=400_EMPTY_BODY HOURLY_GLOBAL_BUDGET=$HourlyBudget"
  Write-Host "BETA_OVERRIDE=$beta"
  Write-Host 'IMPORTANT: keep all FOUR Compose files for subsequent OTP operations.'
 }catch{
  $msg=$_.Exception.Message
  Write-Host "ENABLE_FAILED=$msg; attempting OTP-only rollback"
  docker compose @orig up -d --no-deps --no-build --force-recreate otp
  if($LASTEXITCODE -eq 0){
   $code=Probe '/v1/auth/otp/public-request'
   if($code -eq '503'){Write-Host 'ROLLBACK=PASS PUBLIC_OTP=503'}else{Write-Host "ROLLBACK=INCOMPLETE HTTP=$code"}
  }else{Write-Host 'ROLLBACK=FAILED - manual intervention required'}
  throw $msg
 }
}finally{
 if($wrote -and -not $keep){Remove-Item -LiteralPath $beta -Force -ErrorAction SilentlyContinue}
}
