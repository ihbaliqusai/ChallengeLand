param([string]$Bundle = 'build/app/outputs/bundle/release/app-release.aab')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$audioWorkspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$audioBundlePath = [IO.Path]::GetFullPath((Join-Path $audioWorkspace $Bundle))
$audioRaw = Join-Path $audioWorkspace 'android/app/src/main/res/raw'
$audioLedger = Get-Content -Raw -Encoding utf8 (Join-Path $audioRaw 'audio_provenance.json') | ConvertFrom-Json
$audioBefore = Get-Content -Raw -Encoding utf8 (Join-Path $audioWorkspace 'docs/audio-replacement-before.json') | ConvertFrom-Json
$audioArchive = [IO.Compression.ZipFile]::Open($audioBundlePath,[IO.Compression.ZipArchiveMode]::Read,[Text.Encoding]::UTF8)
function Get-AudioEntryHash([string]$entryName) {
    $audioEntry = $audioArchive.GetEntry($entryName)
    if ($null -eq $audioEntry) { throw "Missing bundled audio asset: $entryName" }
    $audioStream = $audioEntry.Open()
    $audioSha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($audioSha.ComputeHash($audioStream)).Replace('-','') }
    finally { $audioStream.Dispose(); $audioSha.Dispose() }
}
try {
    foreach ($audioRecord in $audioLedger.files) {
        if ((Get-AudioEntryHash ('base/res/raw/' + $audioRecord.file)) -ne $audioRecord.sha256) {
            throw "Stale audio in AAB: $($audioRecord.file)"
        }
    }
    foreach ($audioRetainedName in $audioLedger.retainedLicensedFiles) {
        $audioOriginal = $audioBefore | Where-Object { $_.file -eq $audioRetainedName }
        if ((Get-AudioEntryHash ('base/res/raw/' + $audioRetainedName)) -ne $audioOriginal.sha256) {
            throw "Retained licensed track changed: $audioRetainedName"
        }
    }
    foreach ($audioRestored in $audioLedger.retainedUnverifiedFiles) {
        if ((Get-AudioEntryHash ('base/res/raw/' + $audioRestored.file)) -ne $audioRestored.sha256) {
            throw "Restored recording changed: $($audioRestored.file)"
        }
    }
    $audioWelcomeHash = (Get-FileHash -LiteralPath (Join-Path $audioRaw 'welcome.mp4') -Algorithm SHA256).Hash
    if ((Get-AudioEntryHash 'base/res/raw/welcome.mp4') -ne $audioWelcomeHash) { throw 'Stale welcome video in AAB' }
    $audioLedgerHash = (Get-FileHash -LiteralPath (Join-Path $audioRaw 'audio_provenance.json') -Algorithm SHA256).Hash
    if ((Get-AudioEntryHash 'base/res/raw/audio_provenance.json') -ne $audioLedgerHash) { throw 'Missing or stale audio provenance in AAB' }
    $audioMp3Count = @($audioArchive.Entries | Where-Object { $_.FullName -match '^base/res/raw/.*\.mp3$' }).Count
    if ($audioMp3Count -ne 21) { throw "Unexpected extra or missing audio recordings: $audioMp3Count" }
} finally { $audioArchive.Dispose() }
$audioResult = [pscustomobject]@{
    replacementsVerified=$audioLedger.files.Count
    retainedLicensedTracksVerified=2
    restoredUnverifiedTracksVerified=@($audioLedger.retainedUnverifiedFiles).Count
    provenanceLedgerMatches=$true
    welcomeMatchesMutedSource=$true
    rawMp3Count=$audioMp3Count
    aabBytes=(Get-Item -LiteralPath $audioBundlePath).Length
    aabSha256=(Get-FileHash -LiteralPath $audioBundlePath -Algorithm SHA256).Hash
}
$audioResult | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $audioWorkspace 'scratch/audio-replacement/bundle-validation.json')
$audioResult | Format-List
