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
  & flutter @($step.Args) 2>&1 | Tee-Object -FilePath $log
  $code = $LASTEXITCODE
  if ($code -ne 0) {
    throw "Failed: $($step.Label) (exit=$code). Log: $log"
  }
}
$apk = 'build\app\outputs\flutter-apk\app-debug.apk'
if (-not (Test-Path $apk)) {
  throw "Flutter returned success but no APK was found at $apk"
}
Write-Host "PASS: Flutter analyze, tests and debug APK complete."
Write-Host "APK: $((Resolve-Path $apk).Path)"
Write-Host "Logs: $logDir"
