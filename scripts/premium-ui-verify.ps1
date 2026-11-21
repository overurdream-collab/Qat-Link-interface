# Isolated Maqwati UI branch validation for Windows PowerShell 7 / Windows 11.
# Run from repository root. Does not deploy or change finance data.
$ErrorActionPreference = 'Stop'
$branch = 'feat/maqwati-premium-soft-ui-20261121'
$current = (git branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $current -ne $branch) {
  throw "Expected Git branch $branch; current: $current"
}
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter is not on PATH. Open a Flutter-enabled terminal.'
}
$manifest = 'android\app\src\main\AndroidManifest.xml'
if (-not (Test-Path $manifest)) {
  Write-Host 'No Android scaffold in checkout; generating in a temporary folder.'
  $temporaryScaffold = Join-Path $env:TEMP ('maqwati-android-' + [guid]::NewGuid().ToString('N'))
  & flutter create --no-pub --project-name qat_link --platforms=android --org com.example $temporaryScaffold
  if ($LASTEXITCODE -ne 0) { throw 'Flutter Android scaffold generation failed' }
  Copy-Item -Path (Join-Path $temporaryScaffold 'android') -Destination (Get-Location).Path -Recurse -Force
  Remove-Item -Path $temporaryScaffold -Recurse -Force
}
if (-not (Test-Path $manifest)) { throw 'AndroidManifest.xml still missing after setup' }
$manifestText = [System.IO.File]::ReadAllText((Resolve-Path $manifest).Path)
$manifestText = $manifestText.Replace('android:label="qat_link"', 'android:label="مقوتي"')
[System.IO.File]::WriteAllText((Resolve-Path $manifest).Path, $manifestText, [System.Text.UTF8Encoding]::new($false))
$logDir = Join-Path (Get-Location) 'build\premium-validation'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$steps = @(
  @{ Label = 'pub-get'; Args = @('pub', 'get') },
  @{ Label = 'analyze'; Args = @('analyze', '--no-fatal-infos') },
  @{ Label = 'test'; Args = @('test') },
  @{ Label = 'android-debug'; Args = @('build', 'apk', '--debug') }
)
foreach ($step in $steps) {
  $log = Join-Path $logDir ($step.Label + '.log')
  Write-Host "Running flutter $($step.Args -join ' ') ..."
  $flutterArgs = [string[]]$step.Args
  & flutter @flutterArgs 2>&1 | Tee-Object -FilePath $log
  $code = $LASTEXITCODE
  if ($code -ne 0) {
    throw "Failed: $($step.Label) (exit=$code). Log: $log"
  }
}
$apk = 'build\app\outputs\flutter-apk\app-debug.apk'
if (-not (Test-Path $apk)) {
  throw "Flutter returned success but no APK was found at $apk"
}
$outDir = Join-Path (Get-Location) 'build\\premium-delivery'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$deliveryApk = Join-Path $outDir 'maqwati-premium-debug.apk'
Copy-Item -Path $apk -Destination $deliveryApk -Force
$hash = (Get-FileHash -Path $deliveryApk -Algorithm SHA256).Hash
"$hash  maqwati-premium-debug.apk" | Set-Content -Path (Join-Path $outDir 'SHA256SUMS.txt') -Encoding ascii
$manifestPath = Join-Path $logDir 'build-info.txt'
$details = @(
  'Application: مقوتي',
  'Build type: Android DEBUG only (not a production-signed release)',
  "Branch: $branch",
  "Commit: $(git rev-parse HEAD)",
  "APK: $((Resolve-Path $deliveryApk).Path)",
  "SHA256: $hash"
)
$details | Set-Content -Path $manifestPath -Encoding utf8
Write-Host 'PASS: Flutter analyze, tests and debug APK complete.'
Write-Host "APK: $((Resolve-Path $deliveryApk).Path)"
Write-Host "SHA256: $hash"
Write-Host "Logs: $logDir"
