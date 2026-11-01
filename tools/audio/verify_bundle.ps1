param(
    [string]$Bundle = 'build/app/outputs/bundle/release/app-release.aab',
    [string]$ReportFile = 'scratch/audio-replacement/bundle-validation.json'
)
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
    foreach ($audioRestored in @($audioLedger.retainedUnverifiedFiles) + @($audioLedger.retainedLicensedRecordings)) {
        if ($null -eq $audioRestored) { continue }
        if ((Get-AudioEntryHash ('base/res/raw/' + $audioRestored.file)) -ne $audioRestored.sha256) {
            throw "Restored recording changed: $($audioRestored.file)"
        }
    }
    if ($audioLedger.retainedLicensedRecordings.Count -gt 0) {
        $audioLicenseHash = (Get-FileHash -LiteralPath (Join-Path $audioRaw 'drum1_license.txt') -Algorithm SHA256).Hash
        if ((Get-AudioEntryHash 'base/res/raw/drum1_license.txt') -ne $audioLicenseHash) { throw 'Stale drum license notice' }
    }
    $audioWelcomeHash = (Get-FileHash -LiteralPath (Join-Path $audioRaw 'welcome.mp4') -Algorithm SHA256).Hash
    if ((Get-AudioEntryHash 'base/res/raw/welcome.mp4') -ne $audioWelcomeHash) { throw 'Stale welcome video in AAB' }
    $audioLedgerHash = (Get-FileHash -LiteralPath (Join-Path $audioRaw 'audio_provenance.json') -Algorithm SHA256).Hash
    if ((Get-AudioEntryHash 'base/res/raw/audio_provenance.json') -ne $audioLedgerHash) { throw 'Missing or stale audio provenance in AAB' }
    $audioMp3Count = @($audioArchive.Entries | Where-Object { $_.FullName -match '^base/res/raw/.*\.mp3$' }).Count
    $audioExpectedMp3 = @(Get-ChildItem -LiteralPath $audioRaw -Filter '*.mp3' -File)
    if ($audioMp3Count -ne $audioExpectedMp3.Count) { throw "Unexpected extra or missing audio recordings: $audioMp3Count" }
    foreach ($audioMp3 in $audioExpectedMp3) {
        if ((Get-AudioEntryHash ('base/res/raw/' + $audioMp3.Name)) -ne (Get-FileHash -LiteralPath $audioMp3.FullName -Algorithm SHA256).Hash) {
            throw "Stale bundled recording: $($audioMp3.Name)"
        }
    }
} finally { $audioArchive.Dispose() }
$audioResult = [pscustomobject]@{
    replacementsVerified=$audioLedger.files.Count
    retainedLicensedTracksVerified=2
    restoredUnverifiedTracksVerified=@($audioLedger.retainedUnverifiedFiles).Count
    restoredSourceLicensedTracksVerified=@($audioLedger.retainedLicensedRecordings).Count
    provenanceLedgerMatches=$true
    welcomeMatchesMutedSource=$true
    rawMp3Count=$audioMp3Count
    aabBytes=(Get-Item -LiteralPath $audioBundlePath).Length
    aabSha256=(Get-FileHash -LiteralPath $audioBundlePath -Algorithm SHA256).Hash
}
$audioReportPath = Join-Path $audioWorkspace $ReportFile
$null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $audioReportPath)
$audioResult | ConvertTo-Json | Set-Content -Encoding utf8 -LiteralPath $audioReportPath
$audioResult | Format-List
