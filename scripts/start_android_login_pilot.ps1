# Standalone test-only Caddy and Cloudflare Quick Tunnel; does not touch active FIN25.
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$config=Join-Path $root 'deploy\fin25\Caddyfile.android-login-pilot'
$proxy='maqwati-login-pilot-proxy'
$tunnel='maqwati-login-pilot-tunnel'
$startedProxy=$false
$startedTunnel=$false
function Check-Exit([string]$step) {if($LASTEXITCODE -ne 0){throw "$step failed (exit $LASTEXITCODE)"}}
try {
 if(-not (Test-Path $config)){throw 'Pilot config missing'}
 $existing=@(docker ps -a --format '{{.Names}}');Check-Exit 'Docker inventory'
 if($existing -contains $proxy -or $existing -contains $tunnel){throw 'Test container exists; not overwriting it'}
 $mount=$config+':/etc/caddy/Caddyfile:ro'
 docker run --rm --network fin25-test-net -v $mount caddy:2-alpine caddy validate --config /etc/caddy/Caddyfile
 Check-Exit 'Caddy syntax validation'
 docker run --rm -d --name $proxy --network fin25-test-net -v $mount caddy:2-alpine caddy run --config /etc/caddy/Caddyfile | Out-Null
 Check-Exit 'Separate Caddy startup';$startedProxy=$true
 docker run --rm -d --name $tunnel --network fin25-test-net cloudflare/cloudflared:latest tunnel --no-autoupdate --url "http://$($proxy):8080" | Out-Null
 Check-Exit 'Separate Tunnel startup';$startedTunnel=$true
 $url=$null
 for($i=0;$i -lt 20;$i++){
  Start-Sleep -Seconds 2
  $logs=(& cmd.exe /d /c "docker logs $tunnel 2>&1" | Out-String)
  $found=@([regex]::Matches($logs,'https://[a-zA-Z0-9-]+\.trycloudflare\.com'))
  if($found.Count -gt 0){$url=$found[-1].Value;break}
 }
 if(-not $url){throw 'Temporary HTTPS URL not issued'}
 $health=(& curl.exe -sS -o NUL -w '%{http_code}' --max-time 12 "$url/healthz").Trim();Check-Exit 'Identity health'
 $otp=(& curl.exe -sS -o NUL -w '%{http_code}' --max-time 12 -X POST -H 'content-type: application/json' --data '{}' "$url/v1/auth/otp/request").Trim();Check-Exit 'OTP request restriction'
 $proof=(& curl.exe -sS -o NUL -w '%{http_code}' --max-time 12 -X POST -H 'content-type: application/json' --data '{}' "$url/v1/internal/otp/proof").Trim();Check-Exit 'Internal proof restriction'
 $me=(& curl.exe -sS -o NUL -w '%{http_code}' --max-time 12 "$url/v1/identity/me").Trim();Check-Exit 'Identity authorization check'
 Write-Host "HEALTH=$health OTP_REQUEST=$otp INTERNAL_PROOF=$proof ME=$me"
 if($health -ne '200' -or $otp -ne '403' -or $proof -ne '404' -or $me -ne '401'){throw 'Pilot access controls failed'}
 Write-Host '=== ANDROID LOGIN PILOT READY ==='
 Write-Host "HTTPS_ORIGIN=$url"
 Write-Host 'Use HTTPS_ORIGIN in the Android login pilot. Keep this window open.'
 Write-Host 'Request the SMS only from the local operator computer.'
 Read-Host 'When finished, press ENTER to stop the temporary gateway'
} finally {
 if($startedTunnel){docker stop $tunnel | Out-Null}
 if($startedProxy){docker stop $proxy | Out-Null}
 Write-Host 'Pilot stopped. Existing FIN25 services were not modified.'
}
