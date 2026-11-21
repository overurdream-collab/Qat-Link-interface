# Run from a separate clone on the GREEN branch only, with the ZIP downloaded from ChatGPT.
# Example: powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\import_green_banners.ps1 -ZipPath "C:\Users\...\Downloads\maqwati-green-home-banners-7-originals.zip"
param([Parameter(Mandatory=$true)][string]$ZipPath)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $root
$branch = (& git branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $branch -ne 'feat/maqwati-green-identity-isolated-20261121') {
    throw 'This script may run only in a dedicated clone of the isolated green branch.'
}
if (-not (Test-Path $ZipPath)) { throw "ZIP not found: $ZipPath" }
$expected = @{
    '01-welcome-blue.jpeg' = '0e4607a5dd5fb8a6fee1c498254cf09a898577d165f77ec9fb3362e912cc5d77'
    '02-close-yellow.jpeg' = '51f2b2b725f8466980c623db2ffff8feeffb4f057af172f8c91b2e75a4119621'
    '03-eyes-blue.jpeg' = 'e33805d7041b303086420712e68ca1fd43d4e6ae52ff7b3ed170c7960ede552d'
    '04-welcome-purple.jpeg' = 'c9796d9fd55c760e2e190d986ca5d55bad0fdd5d71b819be658aaf69ce87ec42'
    '05-close-pink.jpeg' = '510f78b68494d1907b834ee244e1d80f074c0e0a4f2c622af875a54fdf74c23f'
    '06-welcome-red.jpeg' = '65484554d8d3d7e871785bac930d2e9e880e33a5ab3fa02292b5a932f6429362'
    '07-happiness-pink.jpeg' = '5a1e701ac1659d7e7615306afedbdca05c24ffa56705b845d044b22d0c2eb837'
}
$zip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path $ZipPath).Path)
try {
    $target = Join-Path $root 'assets\banners'
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    foreach($name in $expected.Keys) {
        $entry = $zip.GetEntry("assets/banners/$name")
        if ($null -eq $entry) { throw "Banner missing from ZIP: $name" }
        $outPath = Join-Path $target $name
        $inputStream = $entry.Open()
        $outputStream = [IO.File]::Create($outPath)
        try { $inputStream.CopyTo($outputStream) }
        finally { $outputStream.Dispose(); $inputStream.Dispose() }
        $actual = (Get-FileHash $outPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $expected[$name]) { throw "Original image checksum mismatch: $name" }
    }
}
finally { $zip.Dispose() }
& git add -- assets/banners
if ($LASTEXITCODE -ne 0) { throw 'Git add failed' }
& git commit -m 'assets(green): add seven exact owner-approved home campaign banners'
if ($LASTEXITCODE -ne 0) { throw 'Git commit failed (or files already committed)' }
& git push origin feat/maqwati-green-identity-isolated-20261121
if ($LASTEXITCODE -ne 0) { throw 'Git push failed' }
Write-Host 'SUCCESS: seven original banners pushed only to the independent green branch.'
