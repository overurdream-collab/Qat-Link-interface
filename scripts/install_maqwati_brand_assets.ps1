<#
.SYNOPSIS
  Prepare the owner's ORIGINAL Maqwati Link mascot art for the Flutter repo.
.DESCRIPTION
  Default is read-only validation. Use -Apply to replace ONLY the two
  assets/images/ files after strict SHA-256 verification. Never modifies
  Android SMS gateway, FIN25 Docker, credentials, or Flutter lock files.
.EXAMPLE
  .\\scripts\\install_maqwati_brand_assets.ps1 -ZipPath ".\\maqwati_brand_full_resolution.zip"
.EXAMPLE
  .\\scripts\\install_maqwati_brand_assets.ps1 -ZipPath ".\\maqwati_brand_full_resolution.zip" -Apply
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $ZipPath,
    [switch] $Apply
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression

$repo = Split-Path -Parent $PSScriptRoot
$archivePath = (Resolve-Path -LiteralPath $ZipPath -ErrorAction Stop).Path
$expected = @(
    @{
        Archive = 'assets/images/maqwati_login_background.jpg'
        Sha256 = '5164ee3d142c7b62bdab6312faf290ceff75852ec8f6260cba82fe434084c748'
        Width = 864; Height = 1536
    },
    @{
        Archive = 'assets/images/maqwati_horizontal_logo.jpg'
        Sha256 = '2765b0d88d3f352f589dac789f1c8dd847293dbfed08fcda9eb665140bf5c12b'
        Width = 1536; Height = 512
    }
)
$temp = Join-Path ([IO.Path]::GetTempPath()) ('maqwati-brand-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($temp) | Out-Null
$verified = @()
try {
    $archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        foreach ($item in $expected) {
            $entry = $archive.GetEntry($item.Archive)
            if ($null -eq $entry) { throw "Missing required original file: $($item.Archive)" }
            if ($entry.Length -lt 50000 -or $entry.Length -gt 15000000) {
                throw "Unexpected asset size for $($item.Archive): $($entry.Length) bytes"
            }
            $staged = Join-Path $temp ([IO.Path]::GetFileName($item.Archive))
            $stream = $entry.Open()
            $targetStream = [IO.File]::Create($staged)
            try { $stream.CopyTo($targetStream) }
            finally { $targetStream.Dispose(); $stream.Dispose() }
            $hash = (Get-FileHash -LiteralPath $staged -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($hash -ne $item.Sha256) {
                throw "The archive contains different image bytes: $($item.Archive)"
            }
            $imgStream = [IO.File]::OpenRead($staged)
            try {
                Add-Type -AssemblyName System.Drawing
                $image = [Drawing.Image]::FromStream($imgStream)
                try {
                    if ($image.Width -ne $item.Width -or $image.Height -ne $item.Height) {
                        throw "Wrong image dimensions: $($item.Archive)"
                    }
                } finally { $image.Dispose() }
            } finally { $imgStream.Dispose() }
            $verified += @{ Item=$item; Path=$staged; Hash=$hash }
            Write-Host ("OK: {0} ({1}x{2}, SHA256 {3})" -f $item.Archive,$item.Width,$item.Height,$hash)
        }
    } finally { $archive.Dispose() }
    if (-not $Apply) {
        Write-Host 'READ ONLY: both original images verified; add -Apply to update project assets.'
        return
    }

    foreach ($v in $verified) {
        $destination = Join-Path $repo ($v.Item.Archive -replace '/', [IO.Path]::DirectorySeparatorChar)
        $parent = Split-Path -Parent $destination
        if (-not [IO.Directory]::Exists($parent)) { throw "Expected project asset folder not found: $parent" }
        # Save the exact former file for quick recovery. Never overwrite backup.
        if ([IO.File]::Exists($destination)) {
            $backup = $destination + '.pre-original.bak'
            if (-not [IO.File]::Exists($backup)) {
                [IO.File]::Copy($destination, $backup, $false)
            }
        }
        [IO.File]::Copy($v.Path, $destination, $true)
        $finalHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($finalHash -ne $v.Hash) { throw "Post-write hash mismatch: $destination" }
        Write-Host "UPDATED: $destination"
    }
    Write-Host 'Done. Run flutter test and inspect PR diff before any git commit/push.'
} finally {
    if ([IO.Directory]::Exists($temp)) {
        [IO.Directory]::Delete($temp,$true)
    }
}
