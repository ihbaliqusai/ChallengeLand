param(
    [Parameter(Mandatory = $true)][string]$Apk,
    [Parameter(Mandatory = $true)][string]$Report
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
$file = Get-Item -LiteralPath $Apk
$zip = [IO.Compression.ZipFile]::Open($file.FullName,
    [IO.Compression.ZipArchiveMode]::Read, [Text.Encoding]::UTF8)
try {
    $entries = @($zip.Entries | ForEach-Object {
        [pscustomobject]@{path=$_.FullName; rawBytes=$_.Length; compressedBytes=$_.CompressedLength}
    })
    $groups = @($entries | Group-Object {
        if ($_.path.StartsWith('assets/flutter_assets/assets/')) { 'Flutter artwork and data' }
        elseif ($_.path.StartsWith('assets/flutter_assets/')) { 'Flutter runtime and fonts' }
        elseif ($_.path.StartsWith('assets/')) { 'Native assets' }
        elseif ($_.path.StartsWith('res/')) { 'Android resources' }
        elseif ($_.path.StartsWith('lib/')) { 'Native libraries' }
        elseif ($_.path -match '^classes.*\.dex$') { 'DEX code' }
        else { 'Other' }
    } | ForEach-Object {
        [pscustomobject]@{group=$_.Name; rawBytes=($_.Group | Measure-Object rawBytes -Sum).Sum;
            compressedBytes=($_.Group | Measure-Object compressedBytes -Sum).Sum; files=$_.Count}
    })
    $result = [pscustomobject]@{
        apk=$file.Name; bytes=$file.Length; sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash;
        groups=$groups; entries=$entries
    }
    $result | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 $Report
    $result | Select-Object apk,bytes,groups | ConvertTo-Json -Depth 4 -Compress
} finally { $zip.Dispose() }
