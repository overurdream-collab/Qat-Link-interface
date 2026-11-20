# Builds an OFFLINE, visually inspectable UI preview only.
# Run from a dedicated clone on the Yemen Modern Fintech design branch.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$branch = (& git branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $branch -ne 'fix/maqwati-yemen-modern-fintech-20261121') {
    throw "Use a dedicated clone on the design branch. Current branch: $branch"
}
if (!(Test-Path 'lib/main_ui_preview.dart')) { throw 'Preview entrypoint missing' }
if (!(Test-Path 'pubspec.yaml')) { throw 'Flutter manifest missing' }

if (!(Test-Path 'android/app/build.gradle.kts')) {
    & flutter create --platforms=android --org com.maqwatilink --project-name qat_link .
    if ($LASTEXITCODE -ne 0) { throw 'Android wrapper generation failed' }
}

$gradle = 'android/app/build.gradle.kts'
$text = [IO.File]::ReadAllText((Resolve-Path $gradle).Path)
if ($text -notmatch 'applicationId\s*=\s*"com\.maqwatilink\.yemen_ui_preview"') {
    if ($text -notmatch 'applicationId\s*=\s*"com\.maqwatilink\.qat_link"') {
        throw 'Unexpected package identity; aborting rather than modifying another app'
    }
    $text = $text.Replace(
        'applicationId = "com.maqwatilink.qat_link"',
        'applicationId = "com.maqwatilink.yemen_ui_preview"'
    )
    [IO.File]::WriteAllText((Resolve-Path $gradle).Path, $text)
}

$manifest = 'android/app/src/main/AndroidManifest.xml'
$xml = [IO.File]::ReadAllText((Resolve-Path $manifest).Path)
if ($xml -match 'android:label="qat_link"') {
    $xml = $xml.Replace('android:label="qat_link"', 'android:label="مقوتي لينك - معاينة"')
    [IO.File]::WriteAllText(
        (Resolve-Path $manifest).Path,
        $xml,
        [Text.UTF8Encoding]::new($false)
    )
}
$gp = 'android/gradle.properties'
if (!(Select-String -Path $gp -Pattern '^kotlin.incremental=false\s*$' -Quiet)) {
    Add-Content -Path $gp -Value "`nkotlin.incremental=false"
}

& flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed' }
& flutter analyze --no-fatal-infos
if ($LASTEXITCODE -ne 0) { throw 'Flutter analysis failed' }
& flutter test test/screens/yemen_modern_fintech_brand_test.dart
if ($LASTEXITCODE -ne 0) { throw 'RTL or brand test failed' }
& flutter test test/screens/yemen_ui_preview_widget_test.dart
if ($LASTEXITCODE -ne 0) { throw 'Preview widget test failed' }
& flutter build apk --release -t lib/main_ui_preview.dart
if ($LASTEXITCODE -ne 0) { throw 'APK build failed' }

$apk = 'build/app/outputs/flutter-apk/app-release.apk'
if (!(Test-Path $apk)) { throw 'Release APK missing' }
$sdk = Join-Path $env:LOCALAPPDATA 'Android/Sdk/build-tools'
$aapt = Get-ChildItem $sdk -Filter aapt.exe -Recurse -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending | Select-Object -First 1
if (!$aapt) { throw 'AAPT missing: cannot verify installed permissions' }
$badging = (& $aapt.FullName dump badging $apk) -join "`n"
$permissions = (& $aapt.FullName dump permissions $apk) -join "`n"
if ($badging -notmatch "name='com\.maqwatilink\.yemen_ui_preview'") {
    throw 'Wrong APK package identity'
}
if ($permissions -match 'android\.permission\.INTERNET') {
    throw 'INTERNET permission found: do not distribute this preview'
}

$output = Join-Path $root 'maqwati-yemen-modern-preview.apk'
Copy-Item $apk $output -Force
Write-Host '=== OFFLINE MAQWATI UI PREVIEW VERIFIED ==='
Get-Item $output | Select-Object FullName, Length, LastWriteTime
Get-FileHash $output -Algorithm SHA256 | Select-Object Algorithm, Hash
