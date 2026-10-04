$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$checkOutput = Join-Path $env:TEMP 'challengeland-campaign-checks'
$nativeSources = Join-Path $repoRoot 'android/app/src/main/java/com/Qi7bali/challengeland'
$compiledApp = Join-Path $repoRoot 'build/app/intermediates/javac/debug/compileDebugJavaWithJavac/classes'
$compiledKotlin = Join-Path $repoRoot 'build/app/tmp/kotlin-classes/debug'
$verificationJson = Join-Path $env:TEMP 'challengeland-json-20240303.jar'
New-Item -ItemType Directory -Path $checkOutput -Force | Out-Null
javac -encoding UTF-8 -d $checkOutput (Join-Path $nativeSources 'Question.java') (Join-Path $nativeSources 'CategoryConfig.java') (Join-Path $nativeSources 'CampaignBoardRules.java') (Join-Path $PSScriptRoot 'CampaignBoardRulesCheck.java')
if ($LASTEXITCODE -ne 0) { throw 'Campaign board checks did not compile' }
java -cp $checkOutput com.qi7bali.landchallengeonline.CampaignBoardRulesCheck
if ($LASTEXITCODE -ne 0) { throw 'Campaign board checks failed' }
if (!(Test-Path -LiteralPath $compiledApp)) { throw 'Build :app:assembleDebug before running progression checks (AppPrefs companion required)' }
if (!(Test-Path -LiteralPath $verificationJson)) {
    Invoke-WebRequest -Uri 'https://repo.maven.apache.org/maven2/org/json/json/20240303/json-20240303.jar' -OutFile $verificationJson -UseBasicParsing
}
if ((Get-FileHash -LiteralPath $verificationJson -Algorithm SHA256).Hash -ne '3CF6CD6892E32E2B4C1C39E0F52F5248A2F5B37646FDFBB79A66B46B618414ED') {
    throw 'JVM JSON verification dependency failed checksum validation'
}
$verificationClasspath = "$checkOutput;$compiledApp;$compiledKotlin;$verificationJson"
$progressionSources = @('AppPrefs.java', 'PlayerProgress.java', 'PlayerStats.java', 'ProgressionAccount.java', 'ProgressionMatchHost.java', 'NativeProgression.java', 'ProgressionRules.java', 'ProgressionSyncState.java') | ForEach-Object { Join-Path $nativeSources $_ }
$verificationSources = @('VerificationContext.java', 'CurrencyClaimsCheck.java', 'NativeProgressionCheck.java') | ForEach-Object { Join-Path $PSScriptRoot $_ }
$androidStubs = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'stubs') -Filter '*.java' -Recurse | ForEach-Object { $_.FullName }
javac -encoding UTF-8 -cp $verificationClasspath -d $checkOutput $androidStubs $progressionSources $verificationSources
if ($LASTEXITCODE -ne 0) { throw 'Native progression checks did not compile' }
java -cp $verificationClasspath com.qi7bali.landchallengeonline.CurrencyClaimsCheck
if ($LASTEXITCODE -ne 0) { throw 'Currency checks failed' }
java -cp $verificationClasspath com.qi7bali.landchallengeonline.NativeProgressionCheck
if ($LASTEXITCODE -ne 0) { throw 'Native progression checks failed' }
