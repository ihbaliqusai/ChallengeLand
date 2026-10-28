param([string]$Bundle = 'build/app/outputs/bundle/release/app-release.aab')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Drawing
$legalWorkspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$legalBundle = [IO.Path]::GetFullPath((Join-Path $legalWorkspace $Bundle))
$legalArchive = [IO.Compression.ZipFile]::OpenRead($legalBundle)

function Read-LegalEntry([string]$name) {
    $legalEntry = $legalArchive.GetEntry($name)
    if ($null -eq $legalEntry) { throw "Missing bundled resource: $name" }
    $legalInput = $legalEntry.Open()
    $legalMemory = New-Object IO.MemoryStream
    try { $legalInput.CopyTo($legalMemory); return ,$legalMemory.ToArray() }
    finally { $legalInput.Dispose(); $legalMemory.Dispose() }
}

function Get-LegalHash([byte[]]$bytes) {
    $legalSha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($legalSha.ComputeHash($bytes)).Replace('-', '') }
    finally { $legalSha.Dispose() }
}

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.IO;
using System.Security.Cryptography;
public static class RightsArtworkPixels {
    public static string Fingerprint(byte[] png) {
        using (var stream = new MemoryStream(png))
        using (var bitmap = new Bitmap(stream))
        using (var hash = SHA256.Create()) {
            var rgba = new byte[bitmap.Width * bitmap.Height * 4];
            int offset = 0;
            for (int y = 0; y < bitmap.Height; y++)
                for (int x = 0; x < bitmap.Width; x++) {
                    var c = bitmap.GetPixel(x, y);
                    rgba[offset++] = c.R; rgba[offset++] = c.G;
                    rgba[offset++] = c.B; rgba[offset++] = c.A;
                }
            return bitmap.Width + "x" + bitmap.Height + ":" +
                BitConverter.ToString(hash.ComputeHash(rgba)).Replace("-", "");
        }
    }
}
'@

try {
    $legalFiles = @(
        'assets/fonts/Baloo-OFL.txt',
        'assets/fonts/NotoSansArabic-OFL.txt',
        'assets/fonts/BarlowCondensed-OFL.txt',
        'assets/licenses/third_party_notices.json'
    )
    foreach ($legalFile in $legalFiles) {
        $legalBundled = Read-LegalEntry ('base/assets/flutter_assets/' + $legalFile)
        $legalSource = [IO.File]::ReadAllBytes((Join-Path $legalWorkspace $legalFile))
        if ((Get-LegalHash $legalBundled) -ne (Get-LegalHash $legalSource)) {
            throw "Stale bundled notice: $legalFile"
        }
    }
    # Inspect every native notice file, including any packaged NOTICE text.
    $legalNativeRoot = Join-Path $legalWorkspace 'android/app/src/main/assets/licenses'
    $legalNativeFiles = @(Get-ChildItem -LiteralPath $legalNativeRoot -File -Recurse)
    if ($legalNativeFiles.Count -eq 0) { throw 'Native notices are missing' }
    foreach ($legalNativeFile in $legalNativeFiles) {
        $legalRelative = $legalNativeFile.FullName.Substring($legalNativeRoot.Length + 1).Replace('\', '/')
        $legalBundled = Read-LegalEntry ('base/assets/licenses/' + $legalRelative)
        if ((Get-LegalHash $legalBundled) -ne (Get-LegalHash ([IO.File]::ReadAllBytes($legalNativeFile.FullName)))) {
            throw "Stale native notice: $legalRelative"
        }
    }
    $legalArtwork = @{
        'assets/ui/million_challenge_logo.png' = 'base/assets/flutter_assets/assets/ui/million_challenge_logo.png'
        'android/app/src/main/res/drawable/avatar13.png' = 'base/res/drawable/avatar13.png'
    }
    foreach ($legalArt in $legalArtwork.GetEnumerator()) {
        $legalSource = [IO.File]::ReadAllBytes((Join-Path $legalWorkspace $legalArt.Key))
        $legalBundled = Read-LegalEntry $legalArt.Value
        if ([RightsArtworkPixels]::Fingerprint($legalSource) -ne [RightsArtworkPixels]::Fingerprint($legalBundled)) {
            throw "Stale artwork pixels: $($legalArt.Key)"
        }
    }
    # Flutter's automatically collected package notices must also still ship.
    $null = Read-LegalEntry 'base/assets/flutter_assets/NOTICES.Z'
    $legalResult = [pscustomobject]@{
        fontsVerified = 3
        flutterNativeNoticeManifestMatches = $true
        nativeNoticeFilesVerified = $legalNativeFiles.Count
        replacementArtworkPixelsVerified = 2
        flutterPackageNoticesPresent = $true
        aabBytes = (Get-Item -LiteralPath $legalBundle).Length
        aabSha256 = (Get-FileHash -LiteralPath $legalBundle -Algorithm SHA256).Hash
    }
    $legalOutput = Join-Path $legalWorkspace 'scratch/ip-completion-2026-10-28'
    $null = New-Item -ItemType Directory -Force -Path $legalOutput
    $legalResult | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $legalOutput 'bundle-validation.json') -Encoding UTF8
    $legalResult | Format-List
} finally { $legalArchive.Dispose() }
