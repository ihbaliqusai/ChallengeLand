param([string]$Serial = 'emulator-5560')

$ErrorActionPreference = 'Stop'
if (!$Serial.StartsWith('emulator-')) {
    throw 'Run scene layout checks on an emulator; this script changes its display settings.'
}
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$adbPath = Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
$screenshots = Join-Path $repoRoot 'build/native-scene-checks'
New-Item -ItemType Directory -Path $screenshots -Force | Out-Null

function Invoke-SceneAdb {
    param([string[]]$AdbArguments)
    $savedPreference = $ErrorActionPreference
    try {
        # Android graphics drivers can write harmless diagnostics to stderr.
        $ErrorActionPreference = 'Continue'
        $output = & $adbPath -s $Serial @AdbArguments 2>&1
        $adbExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = $savedPreference }
    if ($adbExit -ne 0) { throw ($output -join "`n") }
    return $output
}

$originalSize = (Invoke-SceneAdb -AdbArguments @('shell', 'wm', 'size')) -join "`n"
$originalDensity = (Invoke-SceneAdb -AdbArguments @('shell', 'wm', 'density')) -join "`n"
$originalFont = (Invoke-SceneAdb -AdbArguments @('shell', 'settings', 'get', 'system', 'font_scale')).Trim()
$originalRotation = (Invoke-SceneAdb -AdbArguments @('shell', 'settings', 'get', 'system', 'user_rotation')).Trim()
$originalAutoRotation = (Invoke-SceneAdb -AdbArguments @('shell', 'settings', 'get', 'system', 'accelerometer_rotation')).Trim()
try {
    Invoke-SceneAdb -AdbArguments @('install', '-r', (Join-Path $repoRoot 'build/app/outputs/apk/debug/app-debug.apk'))
    Invoke-SceneAdb -AdbArguments @('install', '-r', (Join-Path $repoRoot 'build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk'))
    Invoke-SceneAdb -AdbArguments @('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP')
    Invoke-SceneAdb -AdbArguments @('shell', 'settings', 'put', 'system', 'accelerometer_rotation', '0')
    Invoke-SceneAdb -AdbArguments @('shell', 'settings', 'put', 'system', 'user_rotation', '1')
    Invoke-SceneAdb -AdbArguments @('shell', 'settings', 'put', 'system', 'font_scale', '1.5')
    foreach ($display in @(
        @{ Size = '1080x2092'; Density = '356'; Name = 'reported-phone' },
        @{ Size = '1080x2340'; Density = '440'; Name = 'wide-phone' },
        @{ Size = '1600x2560'; Density = '320'; Name = 'tablet' }
    )) {
        Invoke-SceneAdb -AdbArguments @('shell', 'wm', 'size', $display.Size)
        Invoke-SceneAdb -AdbArguments @('shell', 'wm', 'density', $display.Density)
        $result = (Invoke-SceneAdb -AdbArguments @('shell', 'am', 'instrument', '-w', '-r',
            '-e', 'class', 'com.qi7bali.landchallengeonline.GameSceneLayoutTest',
            'com.qi7bali.landchallengeonline.test/android.test.InstrumentationTestRunner')) -join "`n"
        $result | Set-Content -LiteralPath (Join-Path $screenshots "$($display.Name).log")
        if ($result -notmatch 'OK \(2 tests\)') { throw $result }
        Write-Output "Native scene checks passed: $($display.Name)"
    }
    Invoke-SceneAdb -AdbArguments @('pull', '/sdcard/Android/data/com.qi7bali.landchallengeonline/files/layout-checks', $screenshots)
} finally {
    $restoreSize = if ($originalSize -match 'Override size: (\d+x\d+)') { $Matches[1] } else { 'reset' }
    $restoreDensity = if ($originalDensity -match 'Override density: (\d+)') { $Matches[1] } else { 'reset' }
    Invoke-SceneAdb -AdbArguments @('shell', 'wm', 'size', $restoreSize)
    Invoke-SceneAdb -AdbArguments @('shell', 'wm', 'density', $restoreDensity)
    Invoke-SceneAdb -AdbArguments @('shell', 'settings', 'put', 'system', 'font_scale', $originalFont)
    Invoke-SceneAdb -AdbArguments @('shell', 'settings', 'put', 'system', 'user_rotation', $originalRotation)
    Invoke-SceneAdb -AdbArguments @('shell', 'settings', 'put', 'system', 'accelerometer_rotation', $originalAutoRotation)
}
