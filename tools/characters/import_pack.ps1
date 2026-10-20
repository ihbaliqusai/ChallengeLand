param(
    [Parameter(Mandatory = $true)][string]$SourceDirectory,
    [string]$FfmpegPath = 'C:\Program Files (x86)\CoolerMaster\MasterPlus\ffmpeg.exe',
    [string]$WebpEncoder = ''
)

$ErrorActionPreference = 'Stop'
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (!$WebpEncoder) {
    $WebpEncoder = Join-Path $workspace 'build/size-tools/libwebp-1.6.0-windows-x64/bin/cwebp.exe'
}
foreach ($tool in @($FfmpegPath, $WebpEncoder)) {
    if (!(Test-Path -LiteralPath $tool)) { throw "Required media encoder missing: $tool" }
}
$pack = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'pack.json') -Encoding UTF8 -Raw | ConvertFrom-Json
foreach ($character in $pack) {
    foreach ($suffix in @('', '_correct', '_wrong')) {
        $source = Join-Path $SourceDirectory "video_main$($character.source)$suffix.mp4"
        if (!(Test-Path -LiteralPath $source)) { throw "Missing character clip: $source" }
    }
}
$staging = Join-Path $workspace 'build/character-import'
$flutterAssets = Join-Path $workspace 'assets/characters'
$drawableAssets = Join-Path $workspace 'android/app/src/main/res/drawable'
$rawAssets = Join-Path $workspace 'android/app/src/main/res/raw'
New-Item -ItemType Directory -Path $staging -Force | Out-Null
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -Path (Join-Path $PSScriptRoot 'CharacterArtwork.cs')
$report = @()
foreach ($character in $pack) {
    $id = $character.id
    foreach ($suffix in @('', '_correct', '_wrong')) {
        $source = Join-Path $SourceDirectory "video_main$($character.source)$suffix.mp4"
        $output = Join-Path $rawAssets "video_$id$suffix.mp4"
        # Muted in-game figures: drop unused audio and metadata. Keep the full
        # duration and source frame rate, using the original 9:16 clip aspect.
        & $FfmpegPath -hide_banner -loglevel error -y -i $source -map 0:v:0 -an `
            -vf scale=540:960 -c:v libx264 -preset slow -crf 25 -pix_fmt yuv420p `
            -profile:v main -level:v 3.1 -movflags +faststart -map_metadata -1 $output
        if ($LASTEXITCODE -ne 0) { throw "Video encoding failed: $source" }
        # Decode the entire result, including its last frames, before accepting it.
        & $FfmpegPath -hide_banner -loglevel error -i $output -f null -
        if ($LASTEXITCODE -ne 0) { throw "Video validation failed: $output" }
        $report += [pscustomobject]@{
            source = [IO.Path]::GetFileName($source)
            output = "android/app/src/main/res/raw/video_$id$suffix.mp4"
            sourceBytes = (Get-Item -LiteralPath $source).Length
            outputBytes = (Get-Item -LiteralPath $output).Length
            sourceSha256 = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        }
    }
    $frame = Join-Path $staging "$id-frame.png"
    & $FfmpegPath -hide_banner -loglevel error -y -i (Join-Path $SourceDirectory "video_main$($character.source).mp4") -frames:v 1 $frame
    if ($LASTEXITCODE -ne 0) { throw "Frame extraction failed: $id" }
    $body = Join-Path $staging "$id-body.png"
    $face = Join-Path $staging "$id-face.png"
    [CharacterArtwork]::Prepare($frame, $body, $face)
    foreach ($art in @(@{ input = $body; name = "contestant_$id" }, @{ input = $face; name = $id })) {
        $output = Join-Path $flutterAssets "$($art.name).webp"
        & $WebpEncoder -quiet -lossless -exact -m 6 -q 75 -mt $art.input -o $output
        if ($LASTEXITCODE -ne 0) { throw "Artwork encoding failed: $id" }
        $nativeName = if ($art.name -eq $id) { "emote_$id" } else { $art.name }
        Copy-Item -LiteralPath $output -Destination (Join-Path $drawableAssets "$nativeName.webp") -Force
    }
    Write-Output "Imported $id (3 validated clips, transparent body and avatar)"
}
$report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $staging 'compression-report.json') -Encoding UTF8
$sourceTotal = ($report | Measure-Object sourceBytes -Sum).Sum
$outputTotal = ($report | Measure-Object outputBytes -Sum).Sum
Write-Output ("Videos: {0:N2} MiB -> {1:N2} MiB ({2:N1}% saved)" -f ($sourceTotal / 1MB), ($outputTotal / 1MB), (100 * (1 - $outputTotal / $sourceTotal)))
