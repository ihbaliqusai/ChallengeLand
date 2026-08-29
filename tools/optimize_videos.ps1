# Video Optimization Script for ChallengeLand
# Compresses all raw MP4 videos using H.264 (CRF 28, yuv420p) + AAC (64k) + faststart

$ffmpeg = "C:\Program Files (x86)\CoolerMaster\MasterPlus\ffmpeg.exe"
if (-not (Test-Path $ffmpeg)) {
    $ffmpegCmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if ($ffmpegCmd) { $ffmpeg = $ffmpegCmd.Source }
    else {
        Write-Error "FFmpeg executable not found!"
        exit 1
    }
}

$rawDir = "D:\millionchallengeonline\ChallengeLand\android\app\src\main\res\raw"
$backupDir = "D:\millionchallengeonline\ChallengeLand\tools\backup_videos"

if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}

$videos = Get-ChildItem -Path $rawDir -Filter "*.mp4"

Write-Host "=========================================================="
Write-Host " Starting Video Optimization (Option 1: 720p CRF 28)"
Write-Host " Total Videos to process: $($videos.Count)"
Write-Host "=========================================================="

$totalOriginalBytes = 0
$totalNewBytes = 0

foreach ($vid in $videos) {
    $srcPath = $vid.FullName
    $backupPath = Join-Path $backupDir $vid.Name
    $tempPath = $srcPath + ".opt.mp4"
    $origLen = $vid.Length
    $totalOriginalBytes += $origLen

    # Create backup if not already backed up
    if (-not (Test-Path $backupPath)) {
        Copy-Item -Path $srcPath -Destination $backupPath -Force
    }

    # Compress video
    $argsList = @(
        "-y",
        "-i", $srcPath,
        "-map", "0:v:0",
        "-map", "0:a:0?",
        "-c:v", "libx264",
        "-crf", "28",
        "-preset", "slow",
        "-pix_fmt", "yuv420p",
        "-c:a", "aac",
        "-b:a", "64k",
        "-movflags", "+faststart",
        $tempPath
    )

    $process = Start-Process -FilePath $ffmpeg -ArgumentList $argsList -NoNewWindow -Wait -PassThru

    if ($process.ExitCode -eq 0 -and (Test-Path $tempPath) -and (Get-Item $tempPath).Length -gt 0) {
        $newLen = (Get-Item $tempPath).Length
        $totalNewBytes += $newLen
        Move-Item -Path $tempPath -Destination $srcPath -Force

        $origMB = $origLen / 1MB
        $newMB = $newLen / 1MB
        $savedPct = (1 - ($newLen / $origLen)) * 100

        Write-Host (" [OK] {0,-26} : {1,5:N2} MB -> {2,5:N2} MB  (Saved {3,2:N0}%)" -f $vid.Name, $origMB, $newMB, $savedPct)
    } else {
        Write-Host (" [ERROR] Failed to optimize: {0}" -f $vid.Name) -ForegroundColor Red
        if (Test-Path $tempPath) { Remove-Item $tempPath -Force }
        $totalNewBytes += $origLen
    }
}

Write-Host "=========================================================="
$origTotalMB = $totalOriginalBytes / 1MB
$newTotalMB = $totalNewBytes / 1MB
$totalSavedMB = ($totalOriginalBytes - $totalNewBytes) / 1MB
$totalSavedPct = (1 - ($totalNewBytes / $totalOriginalBytes)) * 100

Write-Host (" Total Original Video Size : {0:N2} MB" -f $origTotalMB)
Write-Host (" Total New Video Size      : {0:N2} MB" -f $newTotalMB)
Write-Host (" Total Space Saved         : {0:N2} MB ({1:N0}%)" -f $totalSavedMB, $totalSavedPct)
Write-Host " Backups safely stored at: $backupDir"
Write-Host "=========================================================="
