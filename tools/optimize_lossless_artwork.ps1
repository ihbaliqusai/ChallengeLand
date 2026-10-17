param(
    [Parameter(Mandatory = $true)][string]$WebpBin,
    [string]$Report = 'build/size-audit/lossless-images.json'
)

# Encoding only: no resizing, palette changes, or lossy recompression. Original
# PNGs remain available as design sources but are excluded from the APK manifest.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class ExactArtworkPixels {
    public static void AssertEqual(string original, string decoded) {
        using (var a = new Bitmap(original)) using (var b = new Bitmap(decoded)) {
            if (a.Size != b.Size) throw new Exception("Image dimensions changed: " + original);
            var rect = new Rectangle(Point.Empty, a.Size);
            var aa = a.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            var bb = b.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            try {
                var x = new byte[a.Width * 4]; var y = new byte[b.Width * 4];
                for (int row = 0; row < a.Height; row++) {
                    Marshal.Copy(IntPtr.Add(aa.Scan0, row * aa.Stride), x, 0, x.Length);
                    Marshal.Copy(IntPtr.Add(bb.Scan0, row * bb.Stride), y, 0, y.Length);
                    for (int i = 0; i < x.Length; i++) if (x[i] != y[i])
                        throw new Exception("RGBA pixels changed: " + original + " row " + row);
                }
            } finally { a.UnlockBits(aa); b.UnlockBits(bb); }
        }
    }
}
'@

$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$encoder = Join-Path $WebpBin 'cwebp.exe'
$decoder = Join-Path $WebpBin 'dwebp.exe'
$verification = Join-Path $workspace 'build/size-audit/decoded-verification.png'
New-Item -ItemType Directory -Path (Split-Path $verification) -Force | Out-Null
$sources = @(
    Get-ChildItem -LiteralPath (Join-Path $workspace 'assets/home') -File -Filter '*.png' |
        Where-Object { $_.Name -ne 'level.png' }
    Get-ChildItem -LiteralPath (Join-Path $workspace 'assets/store') -File -Filter '*.png' |
        Where-Object { $_.Name -ne 'coins.png' }
    foreach ($name in @('home_menu', 'game_modes', 'weekly_reward', 'bg_main', 'bg_login', 'logo', 'person_welcome')) {
        Get-Item -LiteralPath (Join-Path $workspace "assets/ui/$name.png")
    }
)
$results = @()
foreach ($source in $sources) {
    $destination = [IO.Path]::ChangeExtension($source.FullName, '.webp')
    & $encoder -quiet -lossless -exact -m 4 -q 75 -mt $source.FullName -o $destination
    if ($LASTEXITCODE -ne 0) { throw "WebP encoder failed: $($source.Name)" }
    & $decoder -quiet $destination -o $verification
    if ($LASTEXITCODE -ne 0) { throw "WebP decoder failed: $($source.Name)" }
    [ExactArtworkPixels]::AssertEqual($source.FullName, $verification)
    $newSize = (Get-Item -LiteralPath $destination).Length
    $results += [pscustomobject]@{
        source = $source.FullName.Substring($workspace.Length + 1).Replace('\', '/')
        runtime = $destination.Substring($workspace.Length + 1).Replace('\', '/')
        originalBytes = $source.Length
        optimizedBytes = $newSize
        identicalRgba = $true
        useWebp = ($newSize -lt $source.Length)
    }
    Write-Output "$($source.Name): $($source.Length) -> $newSize bytes; identical RGBA"
}
$results | ConvertTo-Json -Depth 3 | Set-Content -Encoding UTF8 (Join-Path $workspace $Report)
Write-Output ("Total saved: {0} bytes" -f (($results | Where-Object useWebp |
    ForEach-Object { $_.originalBytes - $_.optimizedBytes } | Measure-Object -Sum).Sum))
