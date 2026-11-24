[CmdletBinding()]
param(
    [string]$OtpContainer,
    [string]$ExternalUrl,
    [string]$OutputDirectory = (Join-Path $PWD 'fin25-mobile-evidence')
)
$ErrorActionPreference = 'Stop'

# No compose up/down, no env changes, no database writes and no SMS requests.
Get-Command docker -ErrorAction Stop | Out-Null
if (-not $OtpContainer) {
    $candidates = @(& docker ps --filter 'label=com.docker.compose.service=otp' --format '{{.ID}}')
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read running Docker containers.' }
    $candidates = @($candidates | Where-Object { $_ -match '^[a-f0-9]{12,64}$' })
    if ($candidates.Count -ne 1) {
        throw 'Expected exactly one running OTP container. Pass -OtpContainer with the intended container ID.'
    }
    $OtpContainer = $candidates[0]
}
if ($OtpContainer -notmatch '^[a-zA-Z0-9][a-zA-Z0-9_.-]*$') { throw 'Invalid container identifier.' }

$scriptPath = Join-Path $PSScriptRoot 'fin25-mobile-preflight.mjs'
$source = Get-Content -LiteralPath $scriptPath -Raw
$raw = $source | & docker exec -i --workdir /app $OtpContainer node --input-type=module -
if ($LASTEXITCODE -ne 0) { throw 'Read-only FIN25 check failed. No settings were changed.' }
$report = ($raw -join "`n") | ConvertFrom-Json

if ($ExternalUrl) {
    $uri = $null
    if (-not [Uri]::TryCreate($ExternalUrl, [UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -ne 'https' -or $uri.UserInfo -or $uri.Query -or $uri.Fragment -or
        $uri.AbsolutePath -ne '/' -or $uri.IsLoopback) {
        throw 'Use the external HTTPS origin already saved in the gateway, without credentials or a path.'
    }
    $route = [Uri]::new($uri, '/v1/auth/otp/verify')
    $status = 0
    try {
        # Invalid empty verify payload: exercises TLS/API without creating any OTP.
        $response = Invoke-WebRequest -UseBasicParsing -Uri $route -Method Post `
            -ContentType 'application/json' -Body '{}' -TimeoutSec 15 -MaximumRedirection 0
        $status = [int]$response.StatusCode
    } catch {
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
    }
    $report | Add-Member -NotePropertyName externalRoute -NotePropertyValue @{
        expectedStatus = 400
        actualStatus = $status
        reachableWithValidTls = ($status -eq 400)
        sameDatabaseConfirmed = $false
    }
}

$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
if (Test-Path -LiteralPath $adb) {
    $devices = @(& $adb devices | Where-Object { $_ -match '^\S+\s+device$' })
    if ($devices.Count -eq 1) {
        $serial = ($devices[0] -split '\s+')[0]
        $package = 'com.test4.smsgateway.fin25sandbox2026'
        $info = @(& $adb -s $serial shell dumpsys package $package |
            Select-String -Pattern 'versionName=|versionCode=|android.permission.SEND_SMS:|android.permission.READ_PHONE_STATE:')
        $report | Add-Member -NotePropertyName gatewayPackage -NotePropertyValue @{
            package = $package
            details = @($info | ForEach-Object { $_.Line.Trim() })
        }
    }
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$destination = Join-Path $OutputDirectory ('preflight-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $destination -Encoding UTF8
$report | ConvertTo-Json -Depth 8
Write-Host "Evidence saved: $destination"
Write-Host 'No SMS was requested. No service, flag, device approval or database row was changed.'
