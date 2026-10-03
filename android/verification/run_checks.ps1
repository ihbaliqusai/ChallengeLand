$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$checkOutput = Join-Path $env:TEMP 'challengeland-campaign-checks'
$nativeSources = Join-Path $repoRoot 'android/app/src/main/java/com/Qi7bali/challengeland'
$compiledApp = Join-Path $repoRoot 'build/app/intermediates/javac/debug/compileDebugJavaWithJavac/classes'
New-Item -ItemType Directory -Path $checkOutput -Force | Out-Null
javac -encoding UTF-8 -d $checkOutput (Join-Path $nativeSources 'Question.java') (Join-Path $nativeSources 'CategoryConfig.java') (Join-Path $nativeSources 'CampaignBoardRules.java') (Join-Path $PSScriptRoot 'CampaignBoardRulesCheck.java')
if ($LASTEXITCODE -ne 0) { throw 'Campaign board checks did not compile' }
java -cp $checkOutput com.qi7bali.landchallengeonline.CampaignBoardRulesCheck
if ($LASTEXITCODE -ne 0) { throw 'Campaign board checks failed' }
if (!(Test-Path -LiteralPath $compiledApp)) { throw 'Build :app:assembleDebug before running currency checks' }
javac -encoding UTF-8 -cp $compiledApp -d $checkOutput (Join-Path $PSScriptRoot 'stubs/android/content/Context.java') (Join-Path $PSScriptRoot 'stubs/android/content/SharedPreferences.java') (Join-Path $PSScriptRoot 'CurrencyClaimsCheck.java')
if ($LASTEXITCODE -ne 0) { throw 'Currency checks did not compile' }
java -cp "$checkOutput;$compiledApp" com.qi7bali.landchallengeonline.CurrencyClaimsCheck
if ($LASTEXITCODE -ne 0) { throw 'Currency checks failed' }
