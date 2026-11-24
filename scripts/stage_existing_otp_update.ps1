# Stage ONLY the OTP code into the existing detached live worktree.
# Build ONLY the otp image; never restart any running container.
$ErrorActionPreference='Stop'
$integration=Split-Path -Parent $PSScriptRoot
$live='F:\maqwatilink-fin25'
$deploy=Join-Path $live 'deploy\fin25'
$src=Join-Path $integration 'server\src\fin25_otp_transport.mjs'
$dst=Join-Path $live 'server\src\fin25_otp_transport.mjs'
$yaml=Join-Path $deploy 'docker-compose.yml'
$override='F:\maqwatilink-secrets\identity-recovery-20261120\preserve-live.override.json'
$envfile=Join-Path $deploy '.env'
foreach($file in @($src,$dst,$yaml,$override,$envfile)){
 if(-not (Test-Path -LiteralPath $file -PathType Leaf)){throw "Required file missing: $file"}
}
function Check([string]$name){if($LASTEXITCODE -ne 0){throw "$name failed (exit $LASTEXITCODE)"}}
$localChanges=@(git -C $live status --porcelain -- server/src/fin25_otp_transport.mjs deploy/fin25/docker-compose.yml)
Check 'Local worktree inspection'
if($localChanges.Count -gt 0 -and ($localChanges -join '').Trim()){throw 'OTP source or compose is modified locally; refusing replacement'}
$liveOtp=@(docker inspect fin25-test-otp-1 | ConvertFrom-Json)
Check 'Live OTP inspection'
if($liveOtp.Count -ne 1 -or $liveOtp[0].State.Running -ne $true -or
 $liveOtp[0].Config.Labels.'com.docker.compose.service' -ne 'otp' -or
 $liveOtp[0].Config.Labels.'com.docker.compose.project' -ne 'fin25-test'){
 throw 'Unexpected running OTP identity'
}
$oldId=$liveOtp[0].Id;$oldImage=$liveOtp[0].Image
$argsCompose=@('--project-directory',$deploy,'-p','fin25-test','-f',$yaml,'-f',$override,'--env-file',$envfile)
# Effective values are only parsed in memory: do not print credentials.
$beforeJson=(& docker compose @argsCompose config --format json | Out-String)
Check 'Original Compose validation'
$before=$beforeJson | ConvertFrom-Json
if($null -eq $before.services.otp.build){throw 'OTP build context missing'}
if($before.services.otp.environment.OTP_PUBLIC_REQUEST_ENABLED -eq 'true'){throw 'Public OTP already enabled; manual review required'}
$sourceText=[System.IO.File]::ReadAllText($src)
if(-not $sourceText.Contains('OTP_PUBLIC_REQUEST_ENABLED') -or
 -not $sourceText.Contains('/v1/auth/otp/public-request')){throw 'Integration OTP source missing new guard'}
$yamlText=[System.IO.File]::ReadAllText($yaml)
if($yamlText.Contains('OTP_PUBLIC_REQUEST_ENABLED:') -or $yamlText.Contains('OTP_PUBLIC_MAX_PER_HOUR:')){
 throw 'Live Compose already altered for public OTP; manual review required'
}
$needle='      OTP_ENABLED: ${OTP_ENABLED:-false}'
if(-not $yamlText.Contains($needle)){throw 'Expected OTP compose section missing'}
$added=$needle+[Environment]::NewLine+
 '      OTP_PUBLIC_REQUEST_ENABLED: ${OTP_PUBLIC_REQUEST_ENABLED:-false}'+[Environment]::NewLine+
 '      OTP_PUBLIC_MAX_PER_HOUR: ${OTP_PUBLIC_MAX_PER_HOUR:-12}'
$patched=$yamlText.Replace($needle,$added)
$originalSrc=[System.IO.File]::ReadAllBytes($dst)
$originalYaml=[System.IO.File]::ReadAllBytes($yaml)
$backup=Join-Path $deploy ('otp-stage-backup.'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $backup -ErrorAction Stop | Out-Null
[System.IO.File]::WriteAllBytes((Join-Path $backup 'fin25_otp_transport.mjs.original'),$originalSrc)
[System.IO.File]::WriteAllBytes((Join-Path $backup 'docker-compose.yml.original'),$originalYaml)
[System.IO.File]::WriteAllText((Join-Path $backup 'old-image-id.txt'),$oldImage)
Write-Host "BACKUP=$backup"
$ok=$false
try{
 [System.IO.File]::WriteAllText($dst,$sourceText,([System.Text.UTF8Encoding]::new($false)))
 [System.IO.File]::WriteAllText($yaml,$patched,([System.Text.UTF8Encoding]::new($false)))
 $afterJson=(& docker compose @argsCompose config --format json | Out-String)
 Check 'Patched Compose validation'
 $after=$afterJson | ConvertFrom-Json
 $env2=$after.services.otp.environment
 if([string]$env2.OTP_PUBLIC_REQUEST_ENABLED -ne 'false' -or
    [string]$env2.OTP_PUBLIC_MAX_PER_HOUR -ne '12'){
   throw 'Public OTP must remain DISABLED and globally budgeted'
 }
 foreach($prop in $before.services.otp.environment.PSObject.Properties){
   if($prop.Name -in @('OTP_PUBLIC_REQUEST_ENABLED','OTP_PUBLIC_MAX_PER_HOUR')){continue}
   if([string]$prop.Value -cne [string]$env2.($prop.Name)){
     throw "Existing OTP setting changed: $($prop.Name)"
   }
 }
 foreach($service in @('enrollment','https')){
   if(($before.services.$service|ConvertTo-Json -Compress -Depth 30) -cne
      ($after.services.$service|ConvertTo-Json -Compress -Depth 30)){
     throw "Unrelated service config changed: $service"
   }
 }
 Write-Host 'COMPOSE=PASS PUBLIC_OTP=DISABLED'
 docker compose @argsCompose build otp
 Check 'OTP-only image build'
 $still=@(docker inspect fin25-test-otp-1 | ConvertFrom-Json)
 Check 'Running OTP reinspection'
 if($still[0].Id -ne $oldId -or $still[0].Image -ne $oldImage -or
    $still[0].State.Running -ne $true){throw 'Running OTP changed unexpectedly'}
 $ok=$true
 Write-Host 'OTP_STAGE=PASS'
 Write-Host "OLD_RUNNING_IMAGE=$oldImage"
 Write-Host "BACKUP=$backup"
 Write-Host 'The new image is built. No running containers were changed.'
}finally{
 if(-not $ok){
  [System.IO.File]::WriteAllBytes($dst,$originalSrc)
  [System.IO.File]::WriteAllBytes($yaml,$originalYaml)
  Write-Host 'STAGING_FAILED=SOURCE_AND_COMPOSE_RESTORED'
 }
}
