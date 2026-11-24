<#
.SYNOPSIS
  Build the Maqwati Link debug Android preview with the owner's full-res art.
.DESCRIPTION
  Explicit local Windows operation. Installs ONLY two verified original
  branding assets, rejects thumbnails, runs Flutter tests, compiles a debug APK.
  This DOES NOT connect OTP, identity or SMS servers, nor change Docker.
.EXAMPLE
  .\\scripts\\build_maqwati_branded_preview.ps1 -ZipPath "C:\\Assets\\maqwati_brand_full_resolution.zip"
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)] [string]$ZipPath,
  [string]$FlutterExe='flutter',
  [switch]$SkipTests
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
Push-Location $repo
try {
  & (Join-Path $PSScriptRoot 'install_maqwati_brand_assets.ps1') -ZipPath $ZipPath -Apply
  if (-not $?) { throw 'Brand asset installation failed.' }

  $py=Get-Command python -ErrorAction SilentlyContinue
  if ($null -eq $py) { throw 'Python 3 is required to verify the exact original image hashes.' }
  & python scripts/check_maqwati_brand_assets.py --mode release
  if ($LASTEXITCODE -ne 0) { throw 'Release brand asset integrity check failed.' }

  $flutter=Get-Command $FlutterExe -ErrorAction SilentlyContinue
  if ($null -eq $flutter) { throw 'Flutter executable not found.' }

  & $FlutterExe pub get
  if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency resolution failed.' }

  if (-not (Test-Path -LiteralPath 'android/app')) {
    Write-Host 'Android directory missing; generating it only in this local Flutter checkout.'
    & $FlutterExe create --platforms=android --project-name qat_link --org com.maqwati .
    if ($LASTEXITCODE -ne 0) { throw 'Flutter Android project generation failed.' }
  }

  & $FlutterExe analyze --no-fatal-infos
  if ($LASTEXITCODE -ne 0) { throw 'Flutter static analysis failed.' }
  if (-not $SkipTests) {
    & $FlutterExe test
    if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed.' }
  }
  & $FlutterExe build apk --debug --target lib/main.dart
  if ($LASTEXITCODE -ne 0) { throw 'Flutter debug APK build failed.' }

  $apk=Join-Path $repo 'build/app/outputs/flutter-apk/app-debug.apk'
  if (-not (Test-Path -LiteralPath $apk)) { throw "Build output missing: $apk" }
  $sha=(Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash
  Write-Host "SUCCESS: $apk"
  Write-Host "SHA256: $sha"
  Write-Host 'CAUTION: debug design preview ONLY; not a deployed financial login release.'
} finally {
  Pop-Location
}
