param(
    [Parameter(Mandatory = $true)][string]$Apk,
    [string]$Inventory = 'build/app-size-audit-after.json',
    [string]$Aapt2,
    [string]$VideoReport
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
$assets = Get-Content -LiteralPath $Inventory -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $Aapt2) {
    $properties = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../android/local.properties')
    $sdk = (($properties | Where-Object { $_.StartsWith('sdk.dir=') }) -replace '^sdk.dir=', '').Replace('\\', '\')
    $buildTools = Get-ChildItem -LiteralPath (Join-Path $sdk 'build-tools') -Directory |
        Sort-Object { [version]($_.Name -replace '-.*$', '') } -Descending | Select-Object -First 1
    $Aapt2 = Join-Path $buildTools.FullName 'aapt2.exe'
}
# Release builds shorten resource ZIP paths. Resolve symbolic IDs through the
# resource table instead of assuming that res/raw/welcome.mp4 stays that name.
$resourcePaths = @{}
$resourceName = $null
foreach ($line in (& $Aapt2 dump resources $Apk)) {
    if ($line -match '^\s+resource 0x[0-9a-f]+ (\w+/\w+)') { $resourceName = $matches[1] }
    elseif ($resourceName -and $line -match '\(file\) (res/\S+)') {
        $resourcePaths[$resourceName] = $matches[1]
    }
}
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect APK resource table' }
$zip = [IO.Compression.ZipFile]::Open((Get-Item -LiteralPath $Apk).FullName,
    [IO.Compression.ZipArchiveMode]::Read, [Text.Encoding]::UTF8)
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
    $shared = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'shared_assets.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($route in $shared.PSObject.Properties) {
        if ($index.ContainsKey('assets/flutter_assets/' + $route.Name)) {
            throw "Duplicate shared asset shipped in Flutter: $($route.Name)"
        }
        $source = $route.Value -replace '^android/app/src/main/', ''
        if ($source -match '^res/(\w+)/([^/.]+)\.') {
            $symbol = $matches[1] + '/' + $matches[2]
            $source = $resourcePaths[$symbol]
            if (-not $source) { throw "Shared Android resource was stripped: $symbol" }
        }
        if (-not $index.ContainsKey($source)) {
            throw "Canonical Android asset missing: $source"
        }
    }
    if ($index.ContainsKey('assets/questions.json')) { throw 'Duplicate native question bank in APK' }
    if (-not $index.ContainsKey('assets/flutter_assets/assets/questions.json')) { throw 'Shared question bank missing' }
    if ($VideoReport) {
        $videos = Get-Content -LiteralPath $VideoReport -Raw -Encoding UTF8 | ConvertFrom-Json
        $sha256 = [Security.Cryptography.SHA256]::Create()
        try {
            foreach ($clip in $videos.clips) {
                $symbol = 'raw/' + [IO.Path]::GetFileNameWithoutExtension($clip.output)
                $resourcePath = $resourcePaths[$symbol]
                if (-not $resourcePath -or -not $index.ContainsKey($resourcePath)) {
                    throw "Updated video missing from APK: $symbol"
                }
                $stream = $index[$resourcePath].Open()
                try { $hash = [BitConverter]::ToString($sha256.ComputeHash($stream)).Replace('-', '') }
                finally { $stream.Dispose() }
                if ($hash -ne $clip.outputSha256) { throw "APK contains a stale video: $symbol" }
            }
        } finally { $sha256.Dispose() }
        Write-Output "Verified SHA-256 of all $($videos.clips.Count) replacement videos inside APK."
    }
    $runtime = @($zip.Entries | Where-Object { $_.FullName.StartsWith('assets/flutter_assets/assets/') })
    if ($runtime.Count -ne $assets.flutter.count) { throw 'Unexpected extra Flutter assets in APK' }
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName -match '^assets/.*\.(psd|md|bak)$') {
            throw "Non-runtime file in APK: $($entry.FullName)"
        }
    }
    Write-Output "Verified $($runtime.Count) Flutter assets and $(@($shared.PSObject.Properties).Count) shared routes; no duplicate question bank or shared artwork."
} finally { $zip.Dispose() }
