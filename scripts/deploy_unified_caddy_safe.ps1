# Hot-reload the EXISTING FIN25 Caddy config with backup and rollback.
# Does NOT stop, recreate or modify SMS/OTP/Identity/FIN08/Postgres containers.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root 'deploy\fin25\Caddyfile'
$destination = 'F:\maqwatilink-fin25\deploy\fin25\Caddyfile'
$container = 'fin25-test-https-1'
$identityContainer = 'maqwati-identity-p0-identity-1'
$backup = $null
$changed = $false
function Assert-Docker([string]$label) {
  if ($LASTEXITCODE -ne 0) { throw "$label failed (exit $LASTEXITCODE)" }
}
function HttpStatus([string]$path,[string]$method='GET') {
  $result = & curl.exe -sS -k -o NUL -w '%{http_code}' --max-time 10 -X $method "https://localhost:8443$path"
  if ($LASTEXITCODE -ne 0) { throw "HTTP probe failed: $path" }
  return ($result | Select-Object -Last 1).Trim()
}
if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing candidate Caddyfile: $source" }
if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) { throw "Missing live Caddyfile: $destination" }
$sourceContents = Get-Content -LiteralPath $source -Raw
if (-not $sourceContents.Contains('@identity path /healthz /v1/identity/session /v1/identity/me') -or
    -not $sourceContents.Contains('@publicOtp path /v1/auth/otp/public-request')) {
  throw 'Candidate unified Caddyfile is missing expected public routes'
}
if ($sourceContents -match '(?m)^\s*@otp path[^\r\n]*?/v1/internal/otp/proof' -or
    $sourceContents -match '(?m)^\s*handle[^\r\n]*?/v1/internal/otp/proof') {
  throw 'Candidate still exposes the internal proof path'
}
$sourceFull = (Resolve-Path -LiteralPath $source).Path
$destFull = (Resolve-Path -LiteralPath $destination).Path
if ($sourceFull -eq $destFull) { throw 'Source and destination are identical' }
$identity = @(docker inspect $identityContainer | ConvertFrom-Json)
Assert-Docker 'Identity inspect'
$network = $identity[0].NetworkSettings.Networks.'fin25-test-net'
if ($null -eq $network -or @($network.Aliases) -notcontains 'identity') {
  throw "Identity does not advertise alias 'identity' on fin25-test-net; refusing reload"
}
$running = @(docker ps --format '{{.Names}}')
Assert-Docker 'Docker running inventory'
if ($running -notcontains $container -or $running -notcontains $identityContainer) {
  throw 'Caddy or Identity is not running'
}
docker exec $container wget -q -O /dev/null http://identity:8090/healthz
Assert-Docker 'Identity HTTP readiness from Caddy container'
$mounts = @(docker inspect $container | ConvertFrom-Json)
Assert-Docker 'Caddy bind mount inspect'
$liveMount = @($mounts[0].Mounts | Where-Object { $_.Destination -eq '/etc/caddy/Caddyfile' })
if ($liveMount.Count -ne 1 -or $liveMount[0].Source -ne $destination) {
  throw 'Live Caddy bind mount differs from expected path'
}
if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -eq
    (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash) {
  Write-Host 'ALREADY_UP_TO_DATE: file bytes match unified configuration'
  exit 0
}
$image = (docker inspect --format '{{.Config.Image}}' $container | Select-Object -Last 1).Trim()
Assert-Docker 'Caddy image inspect'
$certs = Join-Path (Split-Path -Parent $destination) 'certs'
if (-not (Test-Path -LiteralPath $certs -PathType Container)) { throw 'Live Caddy certificates folder not found' }
# Validate candidate with the same image, certs, and private Docker network.
docker run --rm --network fin25-test-net --mount "type=bind,source=$source,target=/etc/caddy/Caddyfile,readonly" --mount "type=bind,source=$certs,target=/etc/caddy/certs,readonly" $image caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
Assert-Docker 'Candidate Caddy configuration validation'
$backup = "$destination.unified-backup.$(Get-Date -Format yyyyMMdd-HHmmss)"
Copy-Item -LiteralPath $destination -Destination $backup -ErrorAction Stop
Write-Host "BACKUP_CREATED=$backup"
try {
  # Modify in place so the existing bind mount observes the change.
  $bytes=[System.IO.File]::ReadAllBytes($source)
  $stream=[System.IO.File]::Open($destination,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Write,[System.IO.FileShare]::ReadWrite)
  $changed=$true
  try { $stream.SetLength(0);$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true) } finally { $stream.Dispose() }
  $inside=(& docker exec $container cat /etc/caddy/Caddyfile | Out-String)
  Assert-Docker 'Read mounted Caddyfile'
  if (-not $inside.Contains('@identity path /healthz /v1/identity/session /v1/identity/me')) {
    throw 'Mounted Caddyfile is stale; restoring original'
  }
  docker exec $container caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
  Assert-Docker 'Live Caddy validation'
  docker exec $container caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
  Assert-Docker 'Live Caddy hot reload'
  $health=HttpStatus '/healthz'
  $me=HttpStatus '/v1/identity/me'
  $proof=HttpStatus '/v1/internal/otp/proof' 'POST'
  $legacy=HttpStatus '/v1/auth/otp/request' 'POST'
  $public=HttpStatus '/v1/auth/otp/public-request' 'POST'
  Write-Host "HEALTH=$health IDENTITY_ME=$me PRIVATE_PROOF=$proof LOCAL_OTP_REQUEST=$legacy PUBLIC_OTP=$public"
  if ($health -ne '200' -or $me -ne '401' -or $proof -ne '404' -or $legacy -ne '403') {
    throw 'Unified Caddy post-reload acceptance failed'
  }
  Write-Host 'UNIFIED_CADDY=PASS (does NOT authorize public SMS)'
  Write-Host "ROLLBACK_BACKUP=$backup"
  $changed=$false
} catch {
  $errorText=$_.Exception.Message
  if ($changed) {
    Write-Host 'RELOAD_FAILED: restoring prior Caddyfile'
    $bytes=[System.IO.File]::ReadAllBytes($backup)
    $stream=[System.IO.File]::Open($destination,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Write,[System.IO.FileShare]::ReadWrite)
    try { $stream.SetLength(0);$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true) } finally { $stream.Dispose() }
    docker exec $container caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
    if ($LASTEXITCODE -ne 0) {
      throw "Rollback reload FAILED (prior file restored on disk). Original error: $errorText"
    }
    Write-Host 'ROLLBACK=RESTORED'
  }
  throw $errorText
}
