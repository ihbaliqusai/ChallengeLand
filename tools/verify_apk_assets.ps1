param(
    [Parameter(Mandatory = $true)][string]$Apk,
    [string]$Inventory = 'build/app-size-audit-after.json'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$assets = Get-Content -LiteralPath $Inventory -Raw -Encoding UTF8 | ConvertFrom-Json
$zip = [IO.Compression.ZipFile]::OpenRead((Get-Item -LiteralPath $Apk).FullName)
try {
    # Flutter URI-encodes non-ASCII asset names in the APK's ZIP directory.
    $index = @{}
    foreach ($entry in $zip.Entries) { $index[[Uri]::UnescapeDataString($entry.FullName)] = $entry }
    foreach ($asset in $assets.flutter.files) {
        $entry = $index['assets/flutter_assets/' + $asset.path]
        if ($null -eq $entry -or $entry.Length -ne $asset.bytes) {
            throw "Missing or stale bundled asset: $($asset.path)"
        }
    }
    $runtime = @($zip.Entries | Where-Object { $_.FullName.StartsWith('assets/flutter_assets/assets/') })
    if ($runtime.Count -ne $assets.flutter.count) { throw 'Unexpected extra Flutter assets in APK' }
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName -match '^assets/.*\.(psd|md|bak)$') {
            throw "Non-runtime file in APK: $($entry.FullName)"
        }
    }
    Write-Output "Verified $($runtime.Count) runtime assets; no stale originals or design documents in APK."
} finally { $zip.Dispose() }
