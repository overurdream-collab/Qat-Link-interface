param([switch]$Apply)
# Safe promotion of the EXISTING fin25-test OTP container only.
$ErrorActionPreference='Stop'
$d='F:\maqwatilink-fin25\deploy\fin25'
$base=Join-Path $d 'docker-compose.yml'
$preserve='F:\maqwatilink-secrets\identity-recovery-20261120\preserve-live.override.json'
$env=Join-Path $d '.env'
$overlay=Join-Path $d 'otp-unified-promotion.override.yml'
$old='sha256:784837db48892b78b2801fc027021c885fe9782dece551fd6ecf18719fde1a9e'
$new='sha256:310d4573e701066e6bc0c95ceefe3cac4fa5d5e2d11b889715d175b3e705797c'
$container='fin25-test-otp-1'
function Check([string]$label){if($LASTEXITCODE -ne 0){throw "$label failed"}}
function Http([string]$path,[string]$verb='POST'){
 $result= & curl.exe -ksS --max-time 10 -o NUL -w '%{http_code}' -X $verb -H 'content-type: application/json' --data '{}' "https://localhost:8443$path"
 Check "HTTP $path"
 return ($result|Select-Object -Last 1).Trim()
}
foreach($file in @($base,$preserve,$env)){if(-not(Test-Path -LiteralPath $file)){throw "Missing: $file"}}
if(Test-Path -LiteralPath $overlay){throw "Existing override must be reviewed: $overlay"}
$oldRunning=(& docker inspect --format '{{.Image}}' $container|Select-Object -Last 1).Trim()
Check 'Running OTP inspect'
if($oldRunning -ne $old){throw "Live OTP image differs from expected rollback image: $oldRunning"}
$newActual=(& docker image inspect $new --format '{{.Id}}'|Select-Object -Last 1).Trim()
Check 'Candidate image inspect'
if($newActual -ne $new){throw 'Candidate image digest mismatch'}
$compose=@('--project-directory',$d,'-p','fin25-test','-f',$base,'-f',$preserve,'--env-file',$env)
$beforeRaw=(& docker compose @compose config --format json|Out-String)
Check 'Original Compose config'
$before=$beforeRaw|ConvertFrom-Json
if($before.services.otp.image -ne $old){throw 'Current Compose does not pin expected old image'}
$overlayContents=@'
services:
  otp:
    image: sha256:310d4573e701066e6bc0c95ceefe3cac4fa5d5e2d11b889715d175b3e705797c
'@
$success=$false
try{
 [System.IO.File]::WriteAllText($overlay,$overlayContents,([System.Text.UTF8Encoding]::new($false)))
 $candidate=@('--project-directory',$d,'-p','fin25-test','-f',$base,'-f',$preserve,'-f',$overlay,'--env-file',$env)
 $afterRaw=(& docker compose @candidate config --format json|Out-String)
 Check 'Candidate Compose config'
 $after=$afterRaw|ConvertFrom-Json
 if($after.services.otp.image -ne $new){throw 'Candidate image override not applied'}
 foreach($service in @('enrollment','https')){
   if(($before.services.$service|ConvertTo-Json -Compress -Depth 30) -cne
      ($after.services.$service|ConvertTo-Json -Compress -Depth 30)){throw "Unrelated service changed: $service"}
 }
 $a=$before.services.otp.PSObject.Copy()
 $b=$after.services.otp.PSObject.Copy()
 $a.PSObject.Properties.Remove('image')
 $b.PSObject.Properties.Remove('image')
 if(($a|ConvertTo-Json -Compress -Depth 30) -cne ($b|ConvertTo-Json -Compress -Depth 30)){
   throw 'OTP config changed beyond image'
 }
 if([string]$after.services.otp.environment.OTP_PUBLIC_REQUEST_ENABLED -ne 'false'){
   throw 'Public SMS must remain disabled'
 }
 docker run --rm --entrypoint node $new --check /app/src/fin25_otp_transport.mjs
 Check 'New OTP code syntax'
 Write-Host 'OTP_PROMOTION_PREFLIGHT=PASS'
 if(-not $Apply){
   Write-Host 'DRY_RUN=PASS NO_RUNNING_CONTAINERS_CHANGED'
   $success=$true
 }else{
   # Only OTP will be recreated; short SMS service interruption.
   try{
     docker compose @candidate up -d --no-deps --no-build otp
     Check 'OTP-only promotion'
     $now=(& docker inspect --format '{{.Image}}' $container|Select-Object -Last 1).Trim()
     Check 'New OTP inspect'
     if($now -ne $new){throw "Wrong running image: $now"}
     if((Http '/healthz' 'GET') -ne '200'){throw 'Identity health failed'}
     if((Http '/v1/identity/me' 'GET') -ne '401'){throw 'Identity auth failed'}
     if((Http '/v1/internal/otp/proof') -ne '404'){throw 'Internal proof route exposed'}
     if((Http '/v1/auth/otp/request') -ne '403'){throw 'Legacy request protection failed'}
     if((Http '/v1/auth/otp/public-request') -ne '503'){throw 'Public request not fail-closed'}
     $success=$true
     Write-Host 'OTP_PROMOTION=PASS PUBLIC_OTP=503'
     Write-Host "ACTIVE_OVERRIDE=$overlay"
     Write-Host "ROLLBACK_IMAGE=$old"
   }finally{
     if(-not $success){
       Write-Host 'PROMOTION_FAILED: restoring old OTP container only'
       docker compose @compose up -d --no-deps --no-build --force-recreate otp
       if($LASTEXITCODE -ne 0){Write-Host 'ROLLBACK=FAILED NEEDS_MANUAL_ATTENTION'}
       else{
         $restored=(& docker inspect --format '{{.Image}}' $container|Select-Object -Last 1).Trim()
         if($restored -eq $old){Write-Host 'ROLLBACK=PASS'}
         else{Write-Host "ROLLBACK=UNCONFIRMED $restored"}
       }
     }
   }
 }
}finally{
 if(-not $Apply -or -not $success){
   Remove-Item -LiteralPath $overlay -Force -ErrorAction SilentlyContinue
 }
}
